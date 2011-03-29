require "bundler"
require "erb"
require "digest/sha1"

Bundler.require :default

module WordFinda

  require "word_finda/state"
  require "word_finda/game"
  require "word_finda/board"

  class App < Sinatra::Base
    set :root, File.expand_path(__FILE__ + "/../../")

    helpers do
      include Rack::Utils
      alias_method :h, :escape_html
    end

    attr_reader :dalli

    def initialize(*args)
      @dalli = Dalli::Client.new("127.0.0.1:11211")
      super
    end

    # render json
    def json(value)
      content_type :json
      value.to_json
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

      @game = Game.new(@dalli, "main")
      @game.player_join session[:name], session[:id]
      @game.save

      erb :game
    end

    get "/game.json" do
      @game = Game.new(@dalli, "main")
      @game.player_join session[:name], session[:id]
      @game.save

      json @game.commands_for_player(session[:id], (params[:last_command] || -1).to_i)
    end

    post "/game" do
      @game = Game.new(@dalli, "main")

      # .values since it gets posted as a parallel array
      params[:commands].values.each do |command|
        @game.process_command(command, session[:id])
      end

      @game.save

      json @game.commands_for_player(session[:id], (params[:last_command] || -1).to_i)
    end

    get "/game/reset" do
      @game = Game.new(@dalli, "main")
      @game.destroy
      redirect "/game"
    end

  end
end


