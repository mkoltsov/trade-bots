module Helpers
  require 'pathname'
  require 'json'
  require 'yaml'
  require 'telegram/bot'

  def files_dir
    Pathname.new(__FILE__).realpath.parent.parent.parent + 'static'
  end

  def fixture_file(filename)
    files_dir + filename
  end

  def file_json(filename)
    JSON.parse(File.read(fixture_file(filename)))
  end

  def file_yaml(filename)
    YAML.load_file(fixture_file(filename))
  end

  def gdax_creds
    file_yaml("creds.yaml")["GDAX"]
  end

  def coinbase_creds
    file_yaml("creds.yaml")["COINBASE"]
  end

  def telegram_token
    file_yaml("creds.yaml")["TELEGRAM"]["token"]
  end

  def telegram_send(text_to_send)
    Telegram::Bot::Client.run(telegram_token) {|bot| bot.api.send_message(chat_id: '335253154', text: text_to_send.to_s)}
  end

  def preferences
      file_yaml("prefs.yaml")
  end
end