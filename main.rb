#!/usr/bin/env ruby

main_loop= ->(arg) {loop do
  @bot_type="Ticker"
  require './lib/ticker.rb'

  @delay_ticker=preferences['delays']['ticker']
  @thresholds=preferences['thresholds']

  btc_profit = get_profit(@pairs[:bitcoin])
  eth_profit=get_profit(@pairs[:ethereum])
  ltc_profit=get_profit(@pairs[:litecoin])
  profits=[btc_profit, eth_profit, ltc_profit]

  puts "#{btc_profit} #{eth_profit} #{ltc_profit}"
  # binding.pry
  case
    when profits.any? {|i| i<= @thresholds['falling']}
      telegram_send("Losses BTC #{btc_profit} ETH #{eth_profit} LTC #{ltc_profit}")
    when profits.any? {|i| i>= @thresholds['raising']}
      telegram_send("Profits BTC #{btc_profit} ETH #{eth_profit} LTC #{ltc_profit}")
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
          if message.text.match?("historic")
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

