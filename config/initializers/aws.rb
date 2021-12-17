Rails.application.config.action_mailer.perform_deliveries = true
Rails.application.config.action_mailer.raise_delivery_errors = true
Rails.application.config.action_mailer.smtp_settings = {
  address: AwsConfig['smtp_address'], port: 587, user_name: AwsConfig['smtp_username'], password: AwsConfig['smtp_password'],
  authentication: :login, enable_starttls_auto: true
}
