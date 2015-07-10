class DropRecordsTable < ActiveRecord::Migration
    def up
        drop_table :records
    end
    
    def down
        raise ActiveRecord::IrreversibleMigration
    end
end
