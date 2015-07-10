class AddRecordsTable < ActiveRecord::Migration
    def change
        create_table :records do |t|
            t.integer :patient
            t.string :ekg_reading, :limit => 10000
            t.string :blood_pressure, :limit => 10000
            t.integer :sample_rate
            t.integer :num_of_samples
            t.datetime :init_time
            t.binary :data
            
            t.timestamps null: false
        end
    end
end
