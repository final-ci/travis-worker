source 'https://rubygems.org'

ruby '1.9.3', engine: 'jruby', engine_version: '1.7.16' if ENV.key?('DYNO')

gem 'travis-build',     github: 'final-ci/travis-build'
#gem 'travis-build',   path: '../travis-build'
gem 'travis-support',   github: 'final-ci/travis-support'
#gem 'travis-support',   path: '../travis-support'
gem 'travis-guest-api', github: 'final-ci/travis-guest-api'
#gem 'travis-guest-api', path: '../travis-guest-api/'

gem 'celluloid',        git: 'https://github.com/celluloid/celluloid', ref: '5a56056'

gem 'activesupport',    '~> 3.2'

gem 'thor'

gem 'faraday',          '~> 0.7.5'
gem 'hashr',            '~> 0.0.18'
gem 'multi_json',       '~> 1.2.0'
gem 'json'
gem 'coder'

gem 'fog',              '~> 1.25.0'
gem 'travis-saucelabs-api', '~> 0.0'
gem 'docker-api'

gem 'net-ssh',          '~> 2.9.0'
gem 'sshjr',            git: 'https://github.com/joshk/sshjr'

gem 'savon',            '~> 2.11.0', require: nil
gem 'nokogiri',         '~> 1.6.6.2', require: nil

gem 'metriks',          '0.9.9.5'

platform :mri do
  gem 'bunny',            '~> 1.7.0'
end

platform :jruby do
  gem 'march_hare',       '2.7.0'
end


gem 'sentry-raven',     require: 'raven'

group :test do
  gem 'rake',           '~> 0.9.2'
  gem 'mocha',          '~> 0.11.0'
  gem 'rspec'
  gem 'simplecov',      '>= 0.4.0', require: false
  gem 'webmock'
end

gem 'puma'
gem 'sinatra'
gem 'sinatra-contrib'
#gem 'rack-contrib',    github: 'rack/rack-contrib'
gem 'rack-parser', :require => 'rack/parser'



group :development do
  gem 'pry'
end
