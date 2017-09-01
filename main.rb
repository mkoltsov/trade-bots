#!/usr/bin/env ruby

@delay=60

main_loop= ->(arg) {loop do
  @bot_type="Ticker"
  require './lib/ticker.rb'
  btc_profit = get_profit(@pairs[:bitcoin])
  eth_profit=get_profit(@pairs[:ethereum])
  ltc_profit=get_profit(@pairs[:litecoin])
  profits=[btc_profit, eth_profit, ltc_profit]
  puts "#{btc_profit} #{eth_profit}"
  # binding.pry
  case
    when profits.any? {|i| i< -30}
      telegram_send("BTC #{btc_profit} ETH #{eth_profit} LTC #{ltc_profit}")
    when profits.any? {|i| i>= 100}
      telegram_send("BTC #{btc_profit} ETH #{eth_profit} LTC #{ltc_profit}")
    when @closed_orders_number != last_filled.size
      order=last_filled.last
      @closed_orders_number=last_filled.size
      telegram_send("Order closed C:#{order['product_id']} A:#{order['size'].to_f * order['price'].to_f}")
  end

  # puts "------------------------------------------------------"
  sleep(@delay)
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
          bot.api.send_message(chat_id: message.chat.id, text: "BTC #{get_profit(@pairs[:bitcoin])} ETH #{get_profit(@pairs[:ethereum])} LTC #{get_profit(@pairs[:litecoin])}")
        when '/open'
          bot.api.send_message(chat_id: message.chat.id, text: "#{open_orders.empty? ? 'No open orders' : open_orders.pretty_inspect}")
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

