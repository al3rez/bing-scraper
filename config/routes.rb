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

  resources :keyword_uploads, only: [ :index, :create ] do
    collection do
      post :validate
    end
  end
  resources :keywords, only: [ :index, :show ] do
    member do
      get "download_page/:page_id", to: "keywords#download_page", as: :download_page
    end
  end

  # API endpoints
  namespace :api do
    namespace :v1 do
      post "auth/sign_in", to: "authentication#sign_in"
      resources :keywords, only: [ :index, :show ] do
        member do
          get :search_results
        end
      end
      resources :keyword_uploads, only: [ :create ]
    end
  end

  # Swagger API documentation
  mount Rswag::Api::Engine => '/api-docs'
  mount Rswag::Ui::Engine => '/api-docs'

  get "up" => "rails/health#show", :as => :rails_health_check
end
