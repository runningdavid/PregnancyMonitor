class AddRecordTimePeriodToRecords < ActiveRecord::Migration
  def change
    add_column :records, :start_at, :datetime
    add_column :records, :end_at, :datetime
  end
end
