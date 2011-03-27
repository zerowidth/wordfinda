require "bundler"
require "erb"
require "digest/sha1"

Bundler.require :default

module WordFinda

  require "word_finda/game"
  require "word_finda/board"

  class App < Sinatra::Base
    set :root, File.expand_path(__FILE__ + "/../../")

    helpers do
      include Rack::Utils
      alias_method :h, :escape_html
    end

    attr_reader :redis
    attr_reader :game

    def initialize(*args)
      @redis = Redis.new
      @game = Game.new
      super
    end

    get "/" do
      if session[:id]
        erb :index
      else
        erb :welcome
      end
    end

    get "/name" do
      erb :welcome
    end

    post "/name" do
      session[:name] = params[:name]
      session[:id] = Digest::SHA1.hexdigest(params[:name])[0..6]
      redirect "/"
    end

    get "/game" do
      redirect "/" unless session[:id]

      game.player_join session[:name], session[:id]

      erb :game
    end

    get "/game.json" do
    end

  end
end


