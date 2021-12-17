require 'json'

class Service < ApplicationRecord
  PROTOCOLS = { 'GRPC' => 1, 'HTTP' => 2 }
  SERVER_PROG_LANGUAGES = { 'Kotlin' => 1, 'Rails' => 2 }
  CLIENT_PROG_LANGUAGES = { 'Kotlin' => 1 }
  CLOUD_PROVIDERS = { 'None' => 1, 'AWS' => 2 }
  SERVER_INFRASTRUCTURES = { 'None' => 1, 'Fargate' => 2 }
  DEPLOYMENT_INFRASTRUCTURES = { 'None' => 1, 'CodePipeline' => 2 }
  STATUSES = {
    'PENDING' => 1,
    'CREATED' => 2,
    'CREATE_FAILED' => 3,
    'NOT_INITIATED' => 4,
    'CREATE_INITIATED' => 5,
    'DELETE_INITIATED' => 6,
    'DELETE_FAILED' => 7,
    'DELETED' => 8 ,
    'DEPLOY_INITIATED' => 9,
    'DEPLOY_FAILED' => 10,
    'DEPLOYED' => 11,
    'DESTROY_INITIATED' => 12,
    'DESTROY_FAILED' => 13,
    'DESTROYED' => 14,
  }
  KEYS = {
    'Service Protocol' => PROTOCOLS,
    'Server Language' => SERVER_PROG_LANGUAGES,
    'Cloud Provider' => CLOUD_PROVIDERS,
    'Server Infra' => SERVER_INFRASTRUCTURES,
    'CI-CD Infra' => DEPLOYMENT_INFRASTRUCTURES,
  }
  default_scope { where.not(status: STATUSES['DELETED']) }

  TEMPLATE_SERVICE_NAME = 'Starter'.freeze
  TEMPLATE_SERVICE_UNDERSCORE_NAME = TEMPLATE_SERVICE_NAME.underscore.freeze # starter
  TEMPLATE_SERVICE_HYPHEN_NAME = TEMPLATE_SERVICE_UNDERSCORE_NAME.dasherize.freeze # starter
  TEMPLATE_PKG_NAME = 'com.hypto.hws.services'.freeze
  TEMPLATE_PKG_PATH = TEMPLATE_PKG_NAME.gsub('.', '/').freeze

  TMP_DIRECTORY = '.tmp'.freeze
  SERVICE_PROJECT_URL = 'https://github.com/hwslabs/starter-service.git'
  APP_PROJECT_URL = 'https://github.com/hwslabs/starter-app.git'
  RESERVED_PREFIXES = %w(AWS GITHUB)

  GIT_BRANCH = 'main'.freeze
  GIT_REMOTE_NAME = 'hypto-origin'.freeze

  belongs_to :hub, optional: true

  validate :create_validations, on: :create
  after_create_commit :after_create_callbacks

  def rename_package current_path
    exec_cmds = ["cd #{current_path}"]
    exec_cmds << "mkdir -p #{TMP_DIRECTORY}"
    exec_cmds << "mv #{TEMPLATE_PKG_PATH}/* #{TMP_DIRECTORY}"
    exec_cmds << "rm -rf #{TEMPLATE_PKG_PATH.split('/').first.to_s}"
    exec_cmds << "mkdir -p #{@output_pkg_path}"
    exec_cmds << "mv #{TMP_DIRECTORY}/* #{@output_pkg_path}"
    exec_cmds << "rm -rf #{TMP_DIRECTORY}"
    `#{exec_cmds.join(' && ')}`
  end

  def rename_directory current_path, folder_suffix
    exec_cmds = ["cd #{current_path}"]
    exec_cmds << 'git add .'
    exec_cmds << "git mv #{TEMPLATE_SERVICE_HYPHEN_NAME}-#{folder_suffix} #{@output_service_hyphen_name}-#{folder_suffix}"
    `#{exec_cmds.join(' && ')}`
  end

  def replace_pattern current_path, temp_file_name, op_file_name, patterns
    patterns = patterns.map { |keyword| "s/{TEMPLATE_#{keyword}}/#{self.instance_variable_get(keyword.start_with?(*RESERVED_PREFIXES) ? "@#{keyword.downcase}" : "@output_#{keyword.downcase}")}/g" }
    exec_cmds = ["cd #{current_path}"]
    exec_cmds << "sed -i '#{patterns.join('; ')}' #{temp_file_name}"
    exec_cmds << "mv #{temp_file_name} #{op_file_name}" if op_file_name.present?
    puts exec_cmds.join(' && ')
    `#{exec_cmds.join(' && ')}`
  end

  def git_push current_path, repo_name, options = {}
    exec_cmds = ["cd #{current_path}"]
    exec_cmds << "curl -H \"Authorization: token #{@git_access_token}\" -X DELETE https://api.github.com/repos/#{@git_user_name}/#{repo_name}"
    exec_cmds << "curl -H \"Authorization: token #{@git_access_token}\" --data '{\"name\":\"#{repo_name}\"}' https://api.github.com/user/repos"

    exec_cmds <<  "git checkout --orphan #{GIT_BRANCH}"
    exec_cmds << "git remote add #{options['git_remote_name'] || GIT_REMOTE_NAME} #{@git_url_path}/#{repo_name}.git"
    exec_cmds << 'git add .'
    exec_cmds << "git -c user.name='#{@git_user_name}' -c user.email='#{@git_email_id}' commit -m 'Hypto - Initial commit'"
    exec_cmds << "git push -u #{options['git_remote_name'] || GIT_REMOTE_NAME} #{GIT_BRANCH}"
    exec_cmds << "git remote remove #{GIT_REMOTE_NAME}" if options['git_remote_name'].present?

    `#{exec_cmds.join(' && ')}`
  end

  def git_add_submodule(current_path, submodule_path, submodule_name)
    exec_cmds = ["cd #{current_path}"]
    exec_cmds << "git submodule add #{submodule_path}/#{submodule_name}.git"
    exec_cmds << "git submodule update --init --recursive"
    `#{exec_cmds.join(' && ')}`
  end

  def git_reinit_submodule(current_path, old_submodule_name, new_submodule_name)
    exec_cmds = ["cd #{current_path}"]
    exec_cmds << "git submodule deinit -f #{old_submodule_name}"
    exec_cmds << "git rm -rf #{old_submodule_name}"
    exec_cmds << "git submodule add #{@git_submodule_url_path}/#{new_submodule_name}.git"
    exec_cmds << "git submodule update --init --recursive"
    `#{exec_cmds.join(' && ')}`
  end

  def can_deploy?
    self.status == STATUSES['CREATED'] || self.status == STATUSES['DESTROYED']
  end

  def can_destroy?
    self.status == STATUSES['DEPLOYED']
  end

  def can_delete?
    self.status == STATUSES['NOT_INITIATED'] ||
      self.status == STATUSES['CREATED'] ||
      self.status == STATUSES['DESTROYED']
  end

  def deploy_service
    puts "Inside deploy!!"

    @git_user_name = hub.github_user_name
    @git_email_id = hub.github_email_id
    @git_access_token = hub.github_access_token
    @git_url_path = "https://#{@git_user_name}:#{@git_access_token}@github.com/#{@git_user_name}"
    @git_submodule_url_path = "https://github.com/#{@git_user_name}"

    repo_name = "#{self.name.underscore.dasherize}-service"
    exec_cmds = ["rm -rf #{repo_name}"]
    exec_cmds << "curl -H \"Authorization: token #{@git_access_token}\" --data '{\"name\":\"#{repo_name}\"}' https://api.github.com/user/repos"
    exec_cmds << "git clone #{@git_url_path}/#{repo_name}.git --recursive"
    exec_cmds << "pushd #{repo_name}"
    exec_cmds << "./deploy.sh "
    exec_cmds << "popd"
    exec_cmds << "rm -rf #{repo_name}"
    `#{exec_cmds.join(' && ')}`

    self.update!(status: STATUSES['DEPLOYED'])
  end

  def destroy_service
    puts "Inside destroy!!"

    @git_user_name = hub.github_user_name
    @git_email_id = hub.github_email_id
    @git_access_token = hub.github_access_token
    @git_url_path = "https://#{@git_user_name}:#{@git_access_token}@github.com/#{@git_user_name}"
    @git_submodule_url_path = "https://github.com/#{@git_user_name}"

    repo_name = "#{self.name.underscore.dasherize}-service"
    exec_cmds = ["rm -rf #{repo_name}"]
    exec_cmds << "curl -H \"Authorization: token #{@git_access_token}\" --data '{\"name\":\"#{repo_name}\"}' https://api.github.com/user/repos"
    exec_cmds << "git clone #{@git_url_path}/#{repo_name}.git --recursive"
    exec_cmds << "pushd #{repo_name}"
    exec_cmds << "./teardown.sh"
    exec_cmds << "popd"
    exec_cmds << "rm -rf #{repo_name}"
    `#{exec_cmds.join(' && ')}`

    self.update!(status: STATUSES['DESTROYED'])
  end

  def delete_service
    git_access_token = self.hub.github_access_token
    git_user_name = self.hub.github_user_name
    #TODO: Make this conditional on various other fields like, protocol, prog language etc.
    repo_names = []
    meta = JSON.parse(self.meta)
    if meta['source'] == 'CREATE'
      repo_names += %w[service service-infrastructure service-server service-kotlin-client service-models]
    end
    exec_cmds = []
    repo_names.each do |repo|
      repo_name="#{self.name.underscore.dasherize}-#{repo}"
      exec_cmds << "curl -H \"Authorization: token #{git_access_token}\" -X DELETE https://api.github.com/repos/#{git_user_name}/#{repo_name}"
    end
    unless exec_cmds.empty?
      `#{exec_cmds.join(' && ')}`
    end
    self.update!(status: STATUSES['DELETED'])
  end

  # Renaming templates in file contents
  def rename_files(file_mapping)
    file_mapping.each { |mapping| replace_pattern(mapping['path'], mapping['file_name'], mapping['new_file_name'], mapping['patterns']) }
  end

  # Renaming file directories
  def rename_dirs(dir_mapping)
    dir_mapping.each { |mapping| rename_directory(mapping['path'], mapping['folder_suffix']) }
  end

  def construct_infra_and_push(app_path)
    infra_file_mapping = [
      { 'path' => "#{@output_service_hyphen_name}-app/#{TEMPLATE_SERVICE_HYPHEN_NAME}-app-infrastructure",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'package.json' },
      { 'path' => "#{@output_service_hyphen_name}-app/#{TEMPLATE_SERVICE_HYPHEN_NAME}-app-infrastructure/lib",
        'patterns' => ['SERVICE_UNDERSCORE_NAME'], 'file_name' => 'data-layer.ts' },
      { 'path' => "#{@output_service_hyphen_name}-app/#{TEMPLATE_SERVICE_HYPHEN_NAME}-app-infrastructure/lib",
        'patterns' => %w[SERVICE_HYPHEN_NAME SERVICE_NAME AWS_ZONE_NAME APP_NAME], 'file_name' => 'service-layer.ts' },
      { 'path' => "#{@output_service_hyphen_name}-app/#{TEMPLATE_SERVICE_HYPHEN_NAME}-app-infrastructure/lib",
        'patterns' => %w[SERVICE_HYPHEN_NAME SERVICE_NAME], 'file_name' => 'cicd-layer.ts' },
      { 'path' => "#{@output_service_hyphen_name}-app/#{TEMPLATE_SERVICE_HYPHEN_NAME}-app-infrastructure/bin",
        'patterns' => ['SERVICE_NAME'], 'file_name' => 'stack.ts' }
    ]
    rename_files(infra_file_mapping)
    infra_dir_mapping = [
      { 'path' => "#{@output_service_hyphen_name}-app", 'folder_suffix' => 'app-infrastructure' }
    ].freeze
    rename_dirs(infra_dir_mapping)
    infra_path = "#{app_path}/#{@output_service_hyphen_name}-app-infrastructure"
    git_push(infra_path, "#{@output_service_hyphen_name}-app-infrastructure")
    git_reinit_submodule(app_path, "#{@output_service_hyphen_name}-app-infrastructure", "#{@output_service_hyphen_name}-app-infrastructure")
  end

  def construct_app_and_push(app_path)
    app_file_mapping = [
      { 'path' => "#{@output_service_hyphen_name}-app",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'deploy.sh' },
      { 'path' => "#{@output_service_hyphen_name}-app",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'teardown.sh' }
    ]
    rename_files(app_file_mapping)
    git_push(app_path, "#{@output_service_hyphen_name}-app", { 'git_remote_name' => 'origin' })
  end

  def import_server(app_path, repo_owner, repo_name)
    repo_git_url_path = "https://#{@git_user_name}:#{@git_access_token}@github.com/#{repo_owner}"
    git_add_submodule(app_path, repo_git_url_path, repo_name)
  end

  def pull_template_app(app_path)
    `git clone #{APP_PROJECT_URL} #{app_path} -o hypto-origin --recurse-submodules`
  end

  def cleanup(app_path)
    `rm -rf #{app_path}`
  end

  def perform_import(repo_owner, repo_name)
    # Initialize globals
    init_globals
    @output_app_name = repo_name
    app_path = "#{@output_service_hyphen_name}-app"

    # Cleanup workspace
    cleanup(app_path)

    # Pull templatized app
    pull_template_app(app_path)

    # De-templatize and push infra
    construct_infra_and_push(app_path)

    # Import the app server from repo
    import_server(app_path, repo_owner, repo_name)

    # De-templatize files in app and push app
    construct_app_and_push(app_path)

    # Cleanup workspace
    cleanup(app_path)
  end

  def import_service
    return if self.status != STATUSES['NOT_INITIATED']

    # Initiate creation
    puts "Import initiated for app - #{self.inspect}"
    self.update!(status: STATUSES['CREATE_INITIATED'])

    # Get repo owner and name from meta
    meta = JSON.parse(self.meta)
    repo_owner = meta['details']['repo_owner']
    repo_name = meta['details']['repo_name']

    # Perform the import
    perform_import(repo_owner, repo_name)

    # Complete creation
    puts "Import completed for app - #{self.inspect}"
    self.update!(status: STATUSES['CREATED'])
  end

  def init_globals
    hub = self.hub
    @output_service_name = self.name
    @output_service_underscore_name = @output_service_name.underscore # web_flow
    @output_service_hyphen_name = @output_service_underscore_name.dasherize # web-flow

    # Models
    @output_pkg_name = TEMPLATE_PKG_NAME
    @output_pkg_path = @output_pkg_name.gsub('.', '/')

    ########################################
    # Github
    @git_user_name = hub.github_user_name
    @git_email_id = hub.github_email_id
    @git_access_token = hub.github_access_token
    @git_url_path = "https://#{@git_user_name}:#{@git_access_token}@github.com/#{@git_user_name}"
    @git_submodule_url_path = "https://github.com/#{@git_user_name}"

    ########################################
    # AWS
    @self_hosting = self.cloud_provider == CLOUD_PROVIDERS['AWS']
    @aws_zone_name = hub.meta['@aws_zone_name'] || 'hypto.com'
  end

  def create_service
    return if self.status != STATUSES['NOT_INITIATED']
    self.update!(status: STATUSES['CREATE_INITIATED'])

    init_globals


    ########################################
    # Other Constants

    @pattern_mapping = [
      { 'path' => "#{@output_service_hyphen_name}-service",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'deploy.sh' },
      { 'path' => "#{@output_service_hyphen_name}-service",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'teardown.sh' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'docker-compose.yml' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server/docker",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'Dockerfile' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'settings.gradle.kts' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server",
        'patterns' => %w[PKG_NAME SERVICE_NAME SERVICE_HYPHEN_NAME], 'file_name' => 'build.gradle.kts' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server/src/main/kotlin/#{TEMPLATE_PKG_PATH}",
        'patterns' => %w[PKG_NAME SERVICE_NAME], 'file_name' => "#{TEMPLATE_SERVICE_NAME}Server.kt", 'new_file_name' => "#{@output_service_name}Server.kt" },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-models/src/main/proto/#{TEMPLATE_PKG_PATH}",
        'patterns' => %w[PKG_NAME SERVICE_NAME SERVICE_UNDERSCORE_NAME], 'file_name' => "#{TEMPLATE_SERVICE_UNDERSCORE_NAME}_service.proto", 'new_file_name' => "#{@output_service_underscore_name}_service.proto" },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-kotlin-client",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'settings.gradle.kts' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-kotlin-client/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-client",
        'patterns' => %w[PKG_NAME SERVICE_NAME SERVICE_HYPHEN_NAME], 'file_name' => 'build.gradle.kts' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-kotlin-client/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-client/src/main/kotlin/#{TEMPLATE_PKG_PATH}",
        'patterns' => %w[PKG_NAME SERVICE_NAME SERVICE_HYPHEN_NAME AWS_ZONE_NAME], 'file_name' => "#{TEMPLATE_SERVICE_NAME}Client.kt", 'new_file_name' => "#{@output_service_name}Client.kt" },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-infrastructure",
        'patterns' => %w[SERVICE_HYPHEN_NAME SERVICE_NAME AWS_ZONE_NAME], 'file_name' => 'index.ts' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-infrastructure",
        'patterns' => ['SERVICE_HYPHEN_NAME'], 'file_name' => 'package.json' }
    ].freeze
    @package_mapping = %W[
      #{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-models/src/main/proto
      #{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server/src/main/kotlin
      #{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-kotlin-client/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-client/src/main/kotlin
    ].freeze
    @directory_mapping = [
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server", 'folder_suffix' => 'service-models' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-server", 'folder_suffix' => 'service-server' },
      { 'path' => "#{@output_service_hyphen_name}-service/#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-kotlin-client", 'folder_suffix' => 'service-client' },
      { 'path' => "#{@output_service_hyphen_name}-service", 'folder_suffix' => 'service-server' },
      { 'path' => "#{@output_service_hyphen_name}-service", 'folder_suffix' => 'service-kotlin-client' },
      { 'path' => "#{@output_service_hyphen_name}-service", 'folder_suffix' => 'service-infrastructure' }
    ].freeze

    ########################################
    # Cloning template project
    `rm -rf #{@output_service_hyphen_name}-service && git clone #{SERVICE_PROJECT_URL} #{@output_service_hyphen_name}-service -o hypto-origin --recurse-submodules`

    # Renaming templates in file contents
    @pattern_mapping.each { |mapping| replace_pattern(mapping['path'], mapping['file_name'], mapping['new_file_name'], mapping['patterns']) }

    # Renaming packages
    @package_mapping.each { |path| rename_package(path) } if @output_pkg_name != TEMPLATE_PKG_NAME

    # Renaming file directories
    @directory_mapping.each { |mapping| rename_directory(mapping['path'], mapping['folder_suffix']) }

    service_path = "#{@output_service_hyphen_name}-service"
    server_path = "#{service_path}/#{@output_service_hyphen_name}-service-server"
    client_path = "#{service_path}/#{@output_service_hyphen_name}-service-kotlin-client"
    infra_path = "#{service_path}/#{@output_service_hyphen_name}-service-infrastructure"
    server_model_path = "#{server_path}/#{@output_service_hyphen_name}-service-models"

    git_push(server_model_path, "#{@output_service_hyphen_name}-service-models")
    git_reinit_submodule(server_path, "#{@output_service_hyphen_name}-service-models", "#{@output_service_hyphen_name}-service-models")
    git_push(server_path, "#{@output_service_hyphen_name}-service-server")

    git_reinit_submodule(client_path, "#{TEMPLATE_SERVICE_HYPHEN_NAME}-service-models", "#{@output_service_hyphen_name}-service-models")
    git_push(client_path, "#{@output_service_hyphen_name}-service-kotlin-client")

    git_push(infra_path, "#{@output_service_hyphen_name}-service-infrastructure")

    git_reinit_submodule(service_path, "#{@output_service_hyphen_name}-service-server", "#{@output_service_hyphen_name}-service-server")
    git_reinit_submodule(service_path, "#{@output_service_hyphen_name}-service-kotlin-client", "#{@output_service_hyphen_name}-service-kotlin-client")
    git_reinit_submodule(service_path, "#{@output_service_hyphen_name}-service-infrastructure", "#{@output_service_hyphen_name}-service-infrastructure")
    git_push(service_path, "#{@output_service_hyphen_name}-service", { 'git_remote_name' => 'origin' })
    `rm -rf #{@output_service_hyphen_name}-service`

    self.update!(status: STATUSES['CREATED'])
  end

  private

  def create_validations
    self.protocol, self.server_prog_language = PROTOCOLS['GRPC'], SERVER_PROG_LANGUAGES['KOTLIN']
    self.server_infrastructure = SERVER_INFRASTRUCTURES[self.cloud_provider == CLOUD_PROVIDERS['AWS'] ? 'ECS_FARGATE' : 'NOT_APPLICABLE']
    self.status = STATUSES['NOT_INITIATED']

    errors.add(:name, I18n.t('service.validation.name_invalid')) if self.name == 'Starter'

    hub = self.hub
    errors.add(:name, I18n.t('service.validation.github_not_connected')) if hub.github_user_name.blank?
  end

  def after_create_callbacks
    meta = JSON.parse(self.meta)
    source = meta['source']
    case source
    when 'CREATE'
      GrpcServiceGenerator.perform_async(self.id, 'create')
    when 'IMPORT'
      GrpcServiceGenerator.perform_async(self.id, 'import')
    else
      #TODO: Throw some error
    end
  end
end
