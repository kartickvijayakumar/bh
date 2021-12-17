class CreateHubs < ActiveRecord::Migration[6.1]
  def change
    create_table :hubs do |t|
      t.string :email
      t.string :github_user_name
      t.string :github_email_id
      t.string :github_access_token

      t.jsonb :meta, default: {}

      t.timestamps
    end
  end
end
