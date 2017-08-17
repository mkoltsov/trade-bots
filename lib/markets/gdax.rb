require 'coinbase/exchange'
class Gdax
  attr_reader :api
  def initialize(key, secret, passphrase)
      @key=key
      @secret=secret
      @passphrase=passphrase
      @api = Coinbase::Exchange::Client.new(@key, @secret, @passphrase)
  end
end