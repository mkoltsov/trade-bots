# lib = File.expand_path('./lib/', __FILE__)
# $LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require './lib/markets/gdax'
require './lib/helpers/helpers'
require 'pry'

include Helpers

gdax_credentials=gdax_creds

gdax = Gdax.new(gdax_credentials["key"], gdax_credentials["secret"], gdax_credentials["passphrase"]).api

user =`echo $USER`.chomp
host =`echo $HOSTNAME`.chomp

telegram_send("Bot has been launched by #{user} on #{host} at #{Time.now.strftime('%H:%M')}")

# print "What's your desired delay?: "
# delay=gets.chomp.to_i
delay=3600
loop do
  open_orders=gdax.orders.select {|i| i['status']=='open'}.map {|i| "#{i["created_at"]} - #{i["product_id"]} - #{i["price"]} - #{i["size"]} "}
  print open_orders
  telegram_send(open_orders)
  puts

  balance=gdax.accounts.map {|i| "#{i['currency']} - #{i['balance']} - #{i['hold']}"}
  puts balance
  telegram_send(balance)
  telegram_send("BTC:#{gdax.last_trade(product_id: "BTC-EUR")['price'].to_f}, ETH:#{gdax.last_trade(product_id: "ETH-EUR")['price'].to_f}")
  puts "------------------------------------------------------"
  sleep(delay)
end

# eval(gdax.server_epoch)[:iso].slice(0..18)



