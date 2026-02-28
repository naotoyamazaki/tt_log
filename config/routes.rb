Rails.application.routes.draw do
  root "homes#top"
  get 'terms_of_service', to: 'homes#terms_of_service'
  get 'privacy_policy', to: 'homes#privacy_policy'

  get 'login', to: 'user_sessions#new'
  post 'login', to: 'user_sessions#create'
  delete 'logout', to: 'user_sessions#destroy'
  get "up" => "rails/health#show", as: :rails_health_check

  resources :users, only: %i[new create]
  resources :password_resets, only: [:new, :create, :edit, :update]

  resources :match_infos do
    get :autocomplete, on: :collection
  end

  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  require 'sidekiq/web'

  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(username, ENV.fetch("SIDEKIQ_USERNAME")) &
      ActiveSupport::SecurityUtils.secure_compare(password, ENV.fetch("SIDEKIQ_PASSWORD"))
  end

  mount Sidekiq::Web => '/sidekiq'
end
