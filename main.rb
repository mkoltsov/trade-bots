#!/usr/bin/env ruby

def calculate_profit(pair)
  tries||=10
  get_profit(pair)
rescue Coinbase::Exchange::RateLimitError
  if (tries -= 1) > 0
    retry
  else
    puts "The number of retries has been exceeded"
  end
end

#TODO think about saving the max lost period for a better buying opportunity
main_loop= ->(arg) {loop do
  @bot_type="Ticker"
  require './lib/ticker.rb'

  @delay_ticker=preferences['delays']['ticker']
  thresholds=preferences['thresholds']

  btc_profit = calculate_profit(@pairs[:bitcoin])
  eth_profit=calculate_profit(@pairs[:ethereum])
  ltc_profit=calculate_profit(@pairs[:litecoin])

  puts "#{btc_profit} #{eth_profit} #{ltc_profit}"
  # binding.pry

  prices=Hash[@pairs.invert.map{|k,_| [k, get_current_price(k)]}]
  max_prices=Hash[@pairs.invert.map{|k,_| [k, get_key_from_redis("#{k}-MAX")]}]
  min_prices=Hash[@pairs.invert.map{|k,_| [k, get_key_from_redis("#{k}-MIN")]}]

  case
    when update_mins_max(btc_profit, eth_profit, ltc_profit)
      telegram_send("Profit/Loss indicator BTC #{btc_profit} ETH #{eth_profit} LTC #{ltc_profit}")
    # when btc_profit >= thresholds['raising']['btc'], eth_profit >= thresholds['raising']['eth'], ltc_profit  >= thresholds['raising']['ltc']
    #   telegram_send("Profits BTC #{btc_profit} ETH #{eth_profit} LTC #{ltc_profit}")
    when prices.any? {|k, v| v.to_f > max_prices[k].to_f || v.to_f< min_prices[k].to_f}
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
    when @closed_orders_number != last_filled.size
      order=last_filled.last
      @closed_orders_number=last_filled.size
      telegram_send("Order closed C:#{order['product_id']} A:#{order['size'].to_f * order['price'].to_f}")
  end

  # puts "------------------------------------------------------"
  sleep(@delay_ticker)
end}

listen=-> {
  @bot_type="Listen"
  require './lib/ticker.rb'
  Telegram::Bot::Client.run(telegram_token) do |bot|
    bot.listen do |message|
      case message.text
        when '/price'
          bot.api.send_message(chat_id: message.chat.id, text: "BTC:#{get_current_price(@pairs[:bitcoin])} LTC:#{get_current_price(@pairs[:litecoin]) } ETH:#{get_current_price(@pairs[:ethereum]) }")
        when '/max'
          bot.api.send_message(chat_id: message.chat.id, text: "#{@pairs.invert.map{|k,_| [k, get_key_from_redis("#{k}-MAX")]}.inspect}")
        when '/profit_max'
          bot.api.send_message(chat_id: message.chat.id, text: "BTC #{get_key_from_redis('BTC_MAX').inspect} LTC #{get_key_from_redis('LTC_MAX').inspect} ETH #{get_key_from_redis('ETH_MAX').inspect}")
        when '/profit_min'
          bot.api.send_message(chat_id: message.chat.id, text: "BTC #{get_key_from_redis('BTC_MIN').inspect} LTC #{get_key_from_redis('LTC_MIN').inspect} ETH #{get_key_from_redis('ETH_MIN').inspect}")
        when '/min'
          bot.api.send_message(chat_id: message.chat.id, text: "#{@pairs.invert.map{|k,_| [k, get_key_from_redis("#{k}-MIN")]}.inspect}")
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
        else
          if message.text.match?("historic") && (message.text.match?("btc") || message.text.match?("ltc") || message.text.match?("eth"))
            puts message.text
            normalized=-> {"#{message.text.split(' ')[1].upcase}-EUR"}
            bot.api.send_message(chat_id: message.chat.id, text: "Max: #{get_price_limit(normalized.call, :max)} Min: #{get_price_limit(normalized.call, :min)}")
          end
      end
    end
  end
}

case ARGV[0]
  when "--start"
    main_loop.call(ARGV[1])
  when "--listen"
    listen.call
  else
    puts "No arguments provided"
    return
end

