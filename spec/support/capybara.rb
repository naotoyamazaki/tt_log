require 'capybara/rails'
require 'capybara/rspec'

Capybara.default_max_wait_time = 5
Capybara.server = :puma
