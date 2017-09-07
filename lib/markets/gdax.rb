require 'coinbase/exchange'
class Gdax
  attr_reader :api

  def initialize(key, secret, passphrase, sandbox=false)
    @key=key
    @secret=secret
    @passphrase=passphrase
    unless sandbox
      @api = Coinbase::Exchange::Client.new(@key, @secret, @passphrase)
    else
      @api = Coinbase::Exchange::Client.new("fe02e253043a6da2f72dd1bf5b06251c", "e0WPMn+S5xwXKmMjk+uc8DQofXA+ozUJdGPENAQ9m/Q1O0HcRDqoUpkqPO8EUOczWAEB7P7ebvqFHIjR6KpV+A==", "8nyplbqwnx4", api_url: "https://api-public.sandbox.gdax.com")
    end
  end
end