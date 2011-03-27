require "bundler"

Bundler.require :default

$:.push File.expand_path("../lib", __FILE__)
require "word_finda"

use Rack::Session::Cookie, :expire_after => 2592000 # 3 days
run WordFinda::App
