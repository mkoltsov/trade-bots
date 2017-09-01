#!/usr/bin/env ruby

require './lib/ticker.rb'

main_loop= ->(arg) {loop do
  puts arg
  Process.daemon
  btc_profit=calculate_position(update_price(get_bought(@pairs[:bitcoin]))) - calculate_position(get_bought(@pairs[:bitcoin]))
  eth_profit=calculate_position(update_price(get_bought(@pairs[:ethereum]))) - calculate_position(get_bought(@pairs[:ethereum]))
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
    when btc_profit >= 50, eth_profit >= 50
      telegram_send("BTC #{btc_profit} ETH#{eth_profit}")
  end

  # puts "------------------------------------------------------"
  sleep(@delay)
end}

case ARGV[0]
  when "--start"
    main_loop.call(ARGV[1])
  else
    puts "No arguments provided"
    return
end

