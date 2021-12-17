class CreateService < ActiveRecord::Migration[6.1]
  def change
    create_table :services do |t|
      t.string :name
      t.column :hub_id, 'BIGINT'
      t.column :protocol, 'SMALLINT'
      t.column :server_prog_language, 'SMALLINT'
      t.column :cloud_provider, 'SMALLINT'
      t.column :server_infrastructure, 'SMALLINT'
      t.column :deployment_infrastructure, 'SMALLINT'
      t.column :status, 'SMALLINT'

      t.jsonb :meta, default: {}

      t.timestamps
    end
  end
end
