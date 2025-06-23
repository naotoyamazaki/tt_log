source "https://rubygems.org"

ruby "3.2.2"

gem 'rails', '7.1.2'
gem "sprockets-rails"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem 'sorcery', '~> 0.16.5'
gem 'cssbundling-rails'
gem 'ransack'
gem 'twitter'
gem 'dotenv-rails', groups: [:development, :test]
gem 'net-imap'
gem 'net-pop'
gem 'net-smtp'
gem 'sitemap_generator'
gem 'rails-i18n', '~> 7.0'
gem 'pagy'
gem 'sassc-rails'


group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'pry-byebug'
end


group :development do
  gem "web-console"
  gem 'letter_opener_web', '~> 2.0'
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
end


group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem 'webdrivers'
  gem 'database_cleaner-active_record'
  gem 'shoulda-matchers', '~> 5.0'
end
