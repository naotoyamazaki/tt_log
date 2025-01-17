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

  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
