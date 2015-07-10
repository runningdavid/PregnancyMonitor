class AddStatusToPatients < ActiveRecord::Migration
  def change
    add_column :patients, :status, :string
  end
end
