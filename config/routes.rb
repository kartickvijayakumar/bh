Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  root to: 'ui#home'

  namespace :ui, constraints: { subdomain: AppConfig['ui_subdomain'] } do
    get :login
    delete :logout
    get :home
    get :profile
    get :import


    resources :service, only: [:create, :index, :destroy] do
      collection do
        get :connect_github
        delete :revoke_github
        post :deploy
        post :destroy_service
        post :import_service
      end
    end
  end

  mount Sidekiq::Web => '/sidekiq', subdomain: SidekiqSettings['subdomain']

  get '/health', to: proc { [200, {}, ['success']] }

  get '/auth/google_oauth2', as: 'ui_google_login', constraints: { subdomain: AppConfig['ui_subdomain'] }
  get '/auth/google_oauth2/callback' => 'ui#signin', constraints: { subdomain: AppConfig['ui_subdomain'] }

  get '/auth/github', as: 'ui_github_login', constraints: { subdomain: AppConfig['ui_subdomain'] }
  get '/auth/github/callback' => 'ui#connect_github', constraints: { subdomain: AppConfig['ui_subdomain'] }

  get '/auth/failure' => 'ui#login_failure', constraints: { subdomain: AppConfig['ui_subdomain'] }

  get '/*path' => 'application#index', constraints: { subdomain: AppConfig['ui_subdomain'] }
end
