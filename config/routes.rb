Rails.application.routes.draw do
  root "homes#top"

  get 'login', to: 'user_sessions#new'
  post 'login', to: 'user_sessions#create'
  delete 'logout', to: 'user_sessions#destroy'
  get "up" => "rails/health#show", as: :rails_health_check

  resources :users, only: %i[new create]
end
