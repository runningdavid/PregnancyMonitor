class Record < ActiveRecord::Base
    validates :patient,
                presence: true,
                :numericality => {:only_integer => true}
                
    validates :type_id,
                presence: true,
                :numericality => {:only_integer => true}
                
    validates :data,
                presence: true,
                length: {maximum: 10000}
                
    validate :data_is_json
                
    validates :sample_rate,
                :numericality => {:only_integer => true}
    
    validates :num_of_samples,
                :numericality => {:only_integer => true}
    
    validates :start_at,
                presence: true
                
    validates :end_at,
                presence: true
    
    protected
        def data_is_json
            errors.add(:base, 'data is not JSON') if ((JSON.parse(data) rescue ArgumentError) == ArgumentError)
        end
end
