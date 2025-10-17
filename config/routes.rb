Rails.application.routes.draw do
  get "home/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  resources :playlists do
    member do
      get :cards
    end
  end

  get     "/auth/spotify",       to: "spotify_auth#login",      as: :spotify_login
  get     "/spotify/callback",   to: "spotify_auth#callback",   as: :spotify_callback
  delete  "/spotify/disconnect", to: "spotify_auth#disconnect", as: :spotify_disconnect
  get     "/sign_in",            to: "sessions#new",            as: :sign_in
  delete  "/logout",             to: "sessions#destroy",        as: :logout

  # token endpoint for Web Playback SDK later:
  get "/spotify/token", to: "spotify_auth#token", as: :spotify_token

  # returns the spotify uuid  for the Web Playback SDK later:
  get "songs/lookup/:qr_token", to: "songs#lookup"
end
