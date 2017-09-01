#!/usr/bin/env ruby

main_loop= ->(arg) {loop do
  @bot_type="Ticker"
  require './lib/ticker.rb'
  btc_profit = get_profit(@pairs[:bitcoin])
  eth_profit=get_profit(@pairs[:ethereum])
  puts "#{btc_profit} #{eth_profit}"
  # binding.pry
  # open_orders=gdax.orders.select {|i| i['status']=='open'}.map {|i| "#{i["created_at"]} - #{i["product_id"]} - #{i["price"]} - #{i["size"]} "}
  # print open_orders
  # telegram_send(open_orders)
  # puts
  #
  # balance=gdax.accounts.map {|i| "#{i['currency']} - #{i['balance']} - #{i['hold']}"}
  # puts balance
  # telegram_send(balance)
  case
    when btc_profit< -30, eth_profit < -30
      telegram_send("BTC #{btc_profit} ETH #{eth_profit}")
    when btc_profit >= 100, eth_profit >= 100
      telegram_send("BTC #{btc_profit} ETH#{eth_profit}")
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
          bot.api.send_message(chat_id: message.chat.id, text: "BTC #{get_profit(@pairs[:bitcoin])} ETH #{get_profit(@pairs[:ethereum])}")
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

