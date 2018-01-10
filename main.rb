#!/usr/bin/env ruby

require 'httparty'

@opp_lambda=-> e {e['percent_change_7d'].to_f>=100 && e['percent_change_24h'].to_f>0 && e['price_eur'].to_f<=0.01  && e["24h_volume_usd"].to_f>50000 && e["max_supply"]}

def calculate_profit(pair)
  tries||=preferences['retries']
  get_profit(pair)
rescue Exception => e
  if (tries -= 1) > 0
    retry
  else
    puts "The number of retries has been exceeded, #{e}"
  end
end
#TODO save the bought price and sell as soon as it is reached to stop the losses
main_loop= ->(arg) {loop do
  begin
  @bot_type="Ticker"
  require './lib/ticker.rb'
  @delay_ticker=preferences['delays']['ticker']
  # thresholds=preferences['thresholds']
  offsets=preferences['offsets']

  # binding.pry

  prices=Hash[@pairs.invert.map {|k, _| [k, get_current_price(k)]}]
  max_prices=Hash[@pairs.invert.map {|k, _| [k, get_key_from_redis("#{k}-MAX")]}]
  min_prices=Hash[@pairs.invert.map {|k, _| [k, get_key_from_redis("#{k}-MIN")]}]
  bought_prices=Hash[@pairs.invert.map {|k, _| [k, get_key_from_redis("#{k}-BOUGHT")]}]
  candidates=JSON[get_key_from_redis('candidates')]
  puts "precalculations finished"
  new_candidates = JSON.parse(HTTParty.get(preferences['queries']['research']).body).select(&@opp_lambda).map {|el| "#{el['id']}"}.select{|elem| !candidates.index(elem)}
  puts "new candidates #{new_candidates.inspect}"

  if new_candidates.length>0
    puts "got new candidates"
    set_key_in_redis('candidates', candidates + new_candidates)
  end

  if prices.any? {|k, v| v.to_f >= max_prices[k].to_f + offsets['max_price'] || v.to_f < min_prices[k].to_f}
    puts "new max/min #{prices} - #{max_prices} - #{min_prices}"
    prices.each do |k, v|
      if v.to_f> max_prices[k].to_f
        set_key_in_redis("#{k}-MAX", v)
        telegram_send("MAX value for #{k} set to #{v}")
      elsif v.to_f< min_prices[k].to_f
        set_key_in_redis("#{k}-MIN", v)
        telegram_send("MIN value for #{k} set to #{v}")
      end
    end
  end
  case
    when @closed_orders_number != last_filled.size
      order=last_filled.last
      @closed_orders_number=last_filled.size
      set_key_in_redis("#{order['product_id']}-BOUGHT", order['price'])
      telegram_send("Order closed C:#{order['product_id']} A:#{order['size'].to_f * order['price'].to_f}")
    when prices.any? {|k, v| v.to_f <= bought_prices[k].to_f + offsets['bought_price'] && get_account(k).first['balance'].to_f > 0}
      telegram_send("bought price has been REACHED, sell immediately #{prices.select {|k, v| v.to_f <= bought_prices[k].to_f + offsets['bought_price']}.pretty_inspect}") if convert_to_bool(get_key_from_redis("NOTIFICATIONS"))
  end
  rescue Exception => e
    puts "GOT EXCEPTION #{e}"
  end
  # puts "------------------------------------------------------"
  sleep(@delay_ticker)
end}

listen=-> {
  @bot_type="Listen"
  require './lib/ticker.rb'
  @delay_ticker=preferences['delays']['ticker']
  cmk=preferences['coins_interested']
  candidates=JSON[get_key_from_redis('candidates')]
  Telegram::Bot::Client.run(telegram_token) do |bot|

    begin
      bot.listen do |message|

        price_notifier = -> (arr, lamb=nil, query=preferences['queries']['get_price']) {
          exit=false
          until exit do
            begin
              default_selector=-> e {arr.include?(e['id'])}
              selector=lamb||default_selector
              msg = JSON.parse(HTTParty.get(query).body).select(&selector).map {|el| "<pre>#{el['symbol']} - #{el["price_eur"]} - #{el["rank"]} - #{el["percent_change_1h"]}  - #{el["percent_change_24h"]}  - #{el["percent_change_7d"]}</pre>"}
              bot.api.send_message(chat_id: message.chat.id, text: "#{msg}".inspect.delete('[\"]').delete(',').delete('\\'), parse_mode: 'HTML')
              exit=true
            rescue Exception => e
              bot.api.send_message(chat_id: message.chat.id, text: "got #{e}, will retry")
              sleep(@delay_ticker)
            end
          end
        }

        case message.text
          when '/price'
            price_notifier.(cmk)
          when '/candidates'
            price_notifier.(candidates)
          when '/possible'
            possible_lambda=-> e {e['percent_change_7d'].to_f>=150 && e['percent_change_24h'].to_f>0 && e['price_eur'].to_f<=0.01}
            price_notifier.(nil, possible_lambda, preferences['queries']['research'])
          when '/opp'
            price_notifier.(nil, @opp_lambda, preferences['queries']['research'])
          when '/max'
            bot.api.send_message(chat_id: message.chat.id, text: "#{@pairs.invert.map {|k, _| [k, get_key_from_redis("#{k}-MAX")]}.inspect}")
          when '/profit_max'
            bot.api.send_message(chat_id: message.chat.id, text: "BTC #{get_key_from_redis('BTC_MAX').inspect} LTC #{get_key_from_redis('LTC_MAX').inspect} ETH #{get_key_from_redis('ETH_MAX').inspect}")
          when '/profit_min'
            bot.api.send_message(chat_id: message.chat.id, text: "BTC #{get_key_from_redis('BTC_MIN').inspect} LTC #{get_key_from_redis('LTC_MIN').inspect} ETH #{get_key_from_redis('ETH_MIN').inspect}")
          when '/min'
            bot.api.send_message(chat_id: message.chat.id, text: "#{@pairs.invert.map {|k, _| [k, get_key_from_redis("#{k}-MIN")]}.inspect}")
          when '/status'
            bot.api.send_message(chat_id: message.chat.id, text: "#{get_current_state}")
          when '/profit'
            begin
              bot.api.send_message(chat_id: message.chat.id, text: "BTC #{get_profit(@pairs[:bitcoin])} ETH #{get_profit(@pairs[:ethereum])} LTC #{get_profit(@pairs[:litecoin])}")
            rescue Coinbase::Exchange::RateLimitError
              bot.api.send_message(chat_id: message.chat.id, text: "rate limit has been exceeded, try again later")
            end
          when '/open'
            bot.api.send_message(chat_id: message.chat.id, text: "#{open_orders.empty? ? 'No open orders' : open_orders.pretty_inspect}")
          when '/notify on'
            set_key_in_redis("NOTIFICATIONS", "true")
            bot.api.send_message(chat_id: message.chat.id, text: "notifications enabled")
          when '/notify off'
            set_key_in_redis("NOTIFICATIONS", "false")
            bot.api.send_message(chat_id: message.chat.id, text: "notifications disabled")
          else
            if message.text && (message.text.match?("historic") && (message.text.match?("btc") || message.text.match?("ltc") || message.text.match?("eth")))
              puts message.text
              normalized=-> {"#{message.text.split(' ')[1].upcase}-EUR"}
              bot.api.send_message(chat_id: message.chat.id, text: "Max: #{get_price_limit(normalized.(), :max)} Min: #{get_price_limit(normalized.(), :min)}")
            else
              bot.api.send_message(chat_id: message.chat.id, text: "Your command #{message} has not been recognized")
            end
        end
      end
    rescue Exception => e
      puts "GOT EXCEPTION #{e}"
    end
  end
}

case ARGV[0]
  when "--start"
    main_loop.(ARGV[1])
  when "--listen"
    listen.()
  else
    puts "No arguments provided"
    return
end

