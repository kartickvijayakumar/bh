Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, AppConfig['ui_google_client_id'], AppConfig['ui_google_client_secret']
  provider :github, AppConfig['ui_github_client_id'], AppConfig['ui_github_client_secret'], scope: 'user,repo,delete_repo,admin:org'
end

OmniAuth.config.allowed_request_methods = %i[get]
OmniAuth.config.on_failure = Proc.new { |env| OmniAuth::FailureEndpoint.new(env).redirect_to_failure }
OmniAuth.config.silence_get_warning = true
