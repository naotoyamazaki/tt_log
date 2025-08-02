require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module TtLog
  class Application < Rails::Application

    config.load_defaults 7.1

    config.active_record.timestamped_migrations = true

    config.autoload_lib(ignore: %w[assets tasks])

    config.i18n.default_locale = :ja

    config.time_zone = 'Asia/Tokyo'
    config.active_record.default_timezone = :local
  end
end
