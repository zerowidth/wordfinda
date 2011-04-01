source :rubygems

gem "sinatra", "~> 1.2.1", :require => "sinatra/base"
gem "json"
gem "dalli"
gem "hiredis"
gem "redis"

gem "dmarkow-raspell",
  :git => "https://github.com/dmarkow/raspell.git",
  :require => "raspell"

group :development do
  gem "heroku"
  gem "thin"
end

group :test do
  gem "rspec", "~> 2.5.0"
  gem "rack-test"
  gem "jasmine"
end
