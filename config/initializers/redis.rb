RedisConfig = YAML.load_file(File.join(Rails.root, 'config', 'redis.yml'))[Rails.env]
host = ENV.fetch('REDIS_HOST') { RedisConfig['host'] }
puts "BuilderHub: Redis host is #{host}"
$redis = Redis::Namespace.new(RedisConfig['namespace'], redis: Redis.new(host: host, port: RedisConfig['port']))
