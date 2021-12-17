class ApplicationMailer < ActionMailer::Base
  default from: "BuilderHub <#{AppConfig['from_email']}>"
  layout 'mailer'

  before_action :add_inline_attachment!

  def add_inline_attachment!
    attachments.inline['logo.png'] = File.read("#{Rails.root}/app/assets/images/hypto-partner-logo-20211012.png")
  end
end
