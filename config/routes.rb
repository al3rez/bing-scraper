require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users

  devise_scope :user do
    authenticated :user do
      root "dashboard#index", as: :authenticated_root
    end

    unauthenticated do
      root "devise/sessions#new", as: :unauthenticated_root
    end
  end

  # Sidekiq Web UI (protected by authentication)
  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end

  resources :keyword_uploads, only: [ :create ] do
    collection do
      post :validate
    end
  end
  resources :keywords, only: [ :show ] do
    member do
      get "download_page/:page_id", to: "keywords#download_page", as: :download_page
    end
  end

  get "up" => "rails/health#show", :as => :rails_health_check
end
