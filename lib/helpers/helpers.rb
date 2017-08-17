module Helpers
  require 'pathname'
  require 'json'
  require 'yaml'

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
end