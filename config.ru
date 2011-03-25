require "rubygems"
require "bundler"

Bundler.require :default

$:.push File.expand_path("../lib", __FILE__)
require "word_finda"

run WordFinda::App
