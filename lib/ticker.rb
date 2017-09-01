# lib = File.expand_path('./lib/', __FILE__)
# $LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require './lib/markets/gdax'
require './lib/helpers/helpers'
require 'pry'

include Helpers

gdax_credentials=gdax_creds

@gdax = Gdax.new(gdax_credentials["key"], gdax_credentials["secret"], gdax_credentials["passphrase"]).api

user =`echo $USER`.chomp
host =`echo $HOSTNAME`.chomp

telegram_send("Bot has been launched by #{user} on #{host} at #{Time.now.strftime('%H:%M')}")

# print "What's your desired delay?: "
# delay=gets.chomp.to_i

pairs={bitcoin: "BTC-EUR", ethereum: "ETH-EUR", litecoin: "LTC-EUR"}

def get_bought(pair)
  @gdax.orders.select {|i| i["status"]=='done'}.sort_by {|i| i["done_at"]}.select {|i| i['product_id']==pair}.last
end

def update_price(data)
  data.merge({"price" => get_current_price(data['product_id'])})
end

def get_current_price(pair)
  @gdax.last_trade(product_id: pair)['price']
end

def calculate_position(data)
  data['size'].to_f*data['price'].to_f
end

def calculate_historic(data)
  "#{data['product_id']}: #{calculate_position(data)}}"
end

delay=3600
loop do

  btc_profit=calculate_position(update_price(get_bought(pairs[:bitcoin]))) - calculate_position(get_bought(pairs[:bitcoin]))
  eth_profit=calculate_position(update_price(get_bought(pairs[:ethereum]))) - calculate_position(get_bought(pairs[:ethereum]))
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
  sleep(delay)
end

# eval(gdax.server_epoch)[:iso].slice(0..18)



