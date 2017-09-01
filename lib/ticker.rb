# lib = File.expand_path('./lib/', __FILE__)
# $LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require './lib/markets/gdax'
require './lib/helpers/helpers'
require 'pry'

include Helpers

gdax_credentials=gdax_creds

@gdax = Gdax.new(gdax_credentials["key"], gdax_credentials["secret"], gdax_credentials["passphrase"]).api
@delay=3600
@pairs={bitcoin: "BTC-EUR", ethereum: "ETH-EUR", litecoin: "LTC-EUR"}

telegram_send("#{@bot_type} bot has been launched by #{`whoami`.chomp} on #{(`hostname`.chomp)} at #{Time.now.strftime('%H:%M')}")
# print "What's your desired delay?: "
# delay=gets.chomp.to_i



def get_bought(pair)
  @gdax.orders.select {|i| i["status"]=='done'}.sort_by {|i| i["done_at"]}.select {|i| i['product_id']==pair}.last
end

def update_price(data)
  data.merge({'price' => get_current_price(data['product_id'])})
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

def get_current_state
  @gdax.accounts.map{|i| "C:#{i['currency']} B:#{i['balance']} A:#{i['available']} H:#{i['hold']}"}.pretty_inspect
end

def get_profit(pair)
  calculate_position(update_price(get_bought(pair))) - calculate_position(get_bought(pair))
end

# eval(gdax.server_epoch)[:iso].slice(0..18)



