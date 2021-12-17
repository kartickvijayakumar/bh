SidekiqConfig = YAML.load_file(File.join(Rails.root, 'config', 'sidekiq_config.yml'))[Rails.env]
sidekiq_host = ENV.fetch('REDIS_HOST') { SidekiqConfig['host'] }
sidekiq_url = "redis://#{sidekiq_host}:#{SidekiqConfig['port']}"

Sidekiq.configure_server do |config|
  ActiveRecord::Base.logger = Logger.new("#{Rails.root}/log/sidekiq.log")

  config.redis = { :url => sidekiq_url, :namespace => SidekiqConfig['namespace'] }
  config.logger.level = ::Logger::DEBUG

  Rails.logger = Sidekiq.logger
  ActiveRecord::Base.logger = Sidekiq.logger
end

Sidekiq.configure_client do |config|
  config.redis = { :url => sidekiq_url, :namespace => SidekiqConfig['namespace'] }
end

if Rails.env.test?
  require 'sidekiq/testing'
  Sidekiq::Testing.inline!
end

sidekiq_backtrace = Rails.env.production? ? 50 : true
Sidekiq.default_worker_options = { retry: 0, backtrace: sidekiq_backtrace }

require 'sidekiq'
require 'sidekiq/web'

SidekiqSettings = YAML.load_file(File.join(Rails.root, 'config', 'sidekiq.yml'))
Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  [user, password] == [SidekiqSettings['username'], SidekiqSettings['password']]
end
