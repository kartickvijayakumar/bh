class Repo
  include ActiveModel::Model
  include ActiveModel::Validations
  include ActiveModel::AttributeMethods

  attr_accessor :id, :name, :full_name, :owner, :default_branch, :html_url, :private, :fork
  validates :name, :owner, :default_branch, :html_url, presence: true

  def something
  end
end
