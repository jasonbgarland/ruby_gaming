Rails.application.routes.draw do
  root "home#show"

  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[ new create ]
  resource :settings, only: %i[ show update ]
  patch "settings/password", to: "settings#update_password", as: :settings_password

  get "games/search", to: "games#search", as: :games_search
  resources :games, only: %i[ show create ]

  resources :collections do
    resources :collection_games, only: %i[ create destroy ]
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
