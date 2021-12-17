AppConfig = YAML.load_file(File.join(Rails.root, 'config', 'app_config.yml'))[Rails.env]
AwsConfig = YAML.load_file(File.join(Rails.root, 'config', 'aws.yml'))
