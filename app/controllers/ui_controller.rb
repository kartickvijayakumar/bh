class UiController < ApplicationController
  before_action :reset_thread
  before_action :verify_session, except: [:login, :signin, :login_failure]

  def signin
    builder_hub = Hub.fetch_hub(request.env['omniauth.auth'].info.email)
    if builder_hub.class == String
      flash['error'] = builder_hub
      redirect_to ui_login_path
    else
      session['auth_token'] = builder_hub.get_jwt_token
      redirect_to ui_home_path
    end
  end

  def login_failure
    flash['error'] = params[:message]
    
    case params[:strategy]
    when 'github'
      redirect_to ui_service_index_path
    else
      logout
    end
  end

  def connect_github
    github_auth = request.env['omniauth.auth']
    Hub.current.update!(github_email_id: github_auth.info.email, github_user_name: github_auth.extra.raw_info.login,
                        github_access_token: github_auth.credentials.token)

    flash['success'] = 'Connected to Github successfully'
    redirect_to ui_home_path
  end

  def revoke_github
    Hub.current.update!(github_email_id: nil, github_user_name: nil, github_access_token: nil)
    flash['success'] = 'Revoked Github successfully'
    redirect_to ui_home_path
  end

  def home
    @services = Hub.current.services.all
  end

  def logout
    reset_session
    redirect_to ui_login_path
  end

  def paginated_list
    github = Github.new oauth_token: Hub.current.github_access_token
    repos = []
    page = 1

    loop do
      curr_repos = github.repos.list per_page: 100, page: page
      if curr_repos.nil? || curr_repos.empty?
        break
      end
      repos += curr_repos
      page += 1
    end
    repos
  end

  def import
    @github_client = Octokit::Client.new(:access_token => Hub.current.github_access_token)
    @github_client.auto_paginate = true
    @repos = if @github_client.nil? then [] else @github_client.repos end
  end

  private

  def verify_session
    @payload = Hub.validate_token(session['auth_token'])
    hub = @payload.present? ? Hub.find_by_id(@payload['hub_id']) : nil
    if hub.nil? || @payload['expiry_time'] < Time.now.to_i
      flash['warning'] = 'Please login to continue'
      return logout
    end
    hub.make_current
  end

  def reset_thread
    Hub.reset_current
  end
end
