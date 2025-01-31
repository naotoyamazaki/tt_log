Rails.application.config.sorcery.submodules = [:reset_password, :remember_me]

Rails.application.config.sorcery.configure do |config|
  config.user_config do |user|
    user.reset_password_mailer = UserMailer
    user.remember_me_for = 30.days
  end

  config.user_class = "User"
end
