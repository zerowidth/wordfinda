require "bundler"
Bundler.require :default, :test

require "word_finda"

Rspec.configure do |c|
  c.before do
    @dalli = Dalli::Client.new("localhost:11211")
    @dalli.delete "test_state"
  end
end
