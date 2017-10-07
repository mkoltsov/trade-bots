# lib = File.expand_path('./lib/', __FILE__)
# $LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require './lib/markets/gdax'
require './lib/helpers/helpers'
require 'pry'
require 'kraken_client'

include Helpers

gdax_credentials=gdax_creds

@gdax = Gdax.new(gdax_credentials["key"], gdax_credentials["secret"], gdax_credentials["passphrase"]).api

@pairs={bitcoin: "BTC-EUR", ethereum: "ETH-EUR", litecoin: "LTC-EUR"}

def last_filled
  @gdax.orders.select {|i| i["status"]=='done'}.sort_by {|i| i["done_at"]}
end

@closed_orders_number=last_filled.size

telegram_send("#{@bot_type} bot has been launched by #{`whoami`.chomp} on #{(`hostname`.chomp)} at #{Time.now.strftime('%H:%M')}")

# def get_bought(pair)
#   last_filled.select {|i| i['product_id']==pair}.last
# end

# def update_price(data)
#   data.merge({'price' => get_current_price(data['product_id'])})
# end

def get_current_price(pair)
  case
    when @pairs.any? {|k, v| v==pair}
      @gdax.last_trade(product_id: pair)['price']
    when pair=='XRP'
      KrakenClient.load.public.ticker('XRPEUR')['XXRPZEUR']['c'][0]
  end
end

def get_historic_price(pair, start, finish, granularity)
  @gdax.price_history({product_id: pair, start: Time.parse(start), end: Time.parse(finish), granularity: granularity})
end

# def calculate_position(data)
#   data['size'].to_f*data['price'].to_f
# end

# def calculate_historic(data)
#   "#{data['product_id']}: #{calculate_position(data)}}"
# end

def open_orders
  @gdax.orders.select {|i| i['status']=='open'}
end

def get_account(pair)
  @gdax.accounts.select {|i| i['currency']==pair[0, 3]}
end

def calculate_deposits_amount(pair)
  price=->(date) {get_historic_price(pair, Date.parse(date).to_time.to_s, Date.parse(date).next_day.to_time.to_s, 36000).first['close']}
  @gdax.account_history(get_account(pair).first['id']).select {|i| i['type']=='transfer'}.inject(0) {|acc, i| acc + (i['details']['transfer_type']=='deposit' ? i['amount'].to_f * price.call(i["created_at"]).to_f : -(i['amount'].to_f * price.call(i["created_at"]).to_f))}
end

def calculate_balance_by_fills(pair)
  @gdax.fills.select {|i| i['product_id']==pair}.inject(0) {|acc, i| acc + (i['side']=='buy' ? i['size'].to_f * i['price'].to_f : -(i['size'].to_f * i['price'].to_f))}
end

def get_current_state
  @gdax.accounts.map {|i| "C:#{i['currency']} B:#{i['balance']} A:#{i['available']} H:#{i['hold']}"}.pretty_inspect
end

def calculate_euro_balance(pair)
  get_account(pair).first['balance'].to_f * get_current_price(pair).to_f
end

def get_profit(pair)
  calculate_euro_balance(pair) - (calculate_deposits_amount(pair) + calculate_balance_by_fills(pair))
  # calculate_position(update_price(get_bought(pair))) - calculate_position(get_bought(pair))
end

def get_price_limit(pair, func)
  more= ->(a, b) {a>b}
  less= ->(a, b) {a<b}
  reduce= ->(f, a) {
    get_historic_price(pair, Time.now.to_date.prev_month.to_time.to_s, Time.now.to_s, 2592000).inject(a) do |acc, i|
      if f.call(i['close'], acc)
        i['close']
      else
        acc
      end
    end
  }

  if func==:max
    reduce.call(more, 0)
  else
    reduce.call(less, 10000)
  end
end

def update_mins_max(btc_profit, eth_profit, ltc_profit)
  if  btc_profit > get_key_from_redis("BTC_MAX").to_f
    set_key_in_redis("BTC_MAX", btc_profit)
  elsif btc_profit < get_key_from_redis("BTC_MIN").to_f
    set_key_in_redis("BTC_MIN", btc_profit)
    return true
  end

  if ltc_profit > get_key_from_redis("LTC_MAX").to_f
    set_key_in_redis("LTC_MAX", ltc_profit)
  elsif ltc_profit < get_key_from_redis("LTC_MIN").to_f
    set_key_in_redis("LTC_MIN", ltc_profit)
    return true
  end

  if eth_profit < get_key_from_redis("ETH_MIN").to_f
    set_key_in_redis("ETH_MIN", eth_profit)
    return true

  elsif eth_profit> get_key_from_redis("ETH_MAX").to_f
    set_key_in_redis("ETH_MAX", eth_profit)
  end
  return false
end

# eval(gdax.server_epoch)[:iso].slice(0..18)