# lib = File.expand_path('./lib/', __FILE__)
# $LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require './lib/markets/gdax'
require './lib//helpers/helpers'

include Helpers

gdax_credentials=gdax_creds

gdax = Gdax.new(gdax_credentials["key"], gdax_credentials["secret"], gdax_credentials["passphrase"]).api

loop do
  print gdax.orders.select{|i| i['status']=='open'}.map{|i| "#{i["created_at"]} - #{i["product_id"]} - #{i["price"]} - #{i["size"]} "}
  puts "------------------------------------------------------"
  sleep(100)
end
