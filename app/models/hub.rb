class Hub < ApplicationRecord
  has_many :services

  def self.fetch_hub email
    email = email.to_s.downcase
    return I18n.t('validation.invalid', param: 'email') unless email.match(EMAIL_REGEX)

    hub = Hub.where(email: email).first_or_create!
    return hub
  end

  def get_jwt_token
    JWT.encode({ 'hub_id' => self.id, 'expiry_time' => (Time.now + 1.day).to_i }, AppConfig['ui_auth'])
  end

  def self.validate_token jwt_token
    begin
      return JWT.decode(jwt_token, AppConfig['ui_auth'])[0].to_h
    rescue => e
      return {}
    end
  end

  def make_current
    Thread.current[:admin_user] = self
  end

  def self.reset_current
    Thread.current[:admin_user] = nil
  end

  def self.current
    Thread.current[:admin_user]
  end
end
