require "bundler"

Bundler.require :default

module WordFinda

  class App < Sinatra::Base
    set :root, File.expand_path(__FILE__ + "/../../")

    helpers do
      include Rack::Utils
      alias_method :h, :escape_html
    end

    def initialize(*args)
      super
    end

    get "/" do
      "let's play!"
    end
  end
end


