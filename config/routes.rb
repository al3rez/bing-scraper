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

  resources :keyword_uploads, only: [:index, :create]
  resources :keywords, only: [:index]

  get "up" => "rails/health#show", :as => :rails_health_check
end
