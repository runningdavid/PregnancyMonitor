class Patient < ActiveRecord::Base
    validates :name, presence: true, length: {maximum: 50}
    validates :description, length: {maximum: 250}
    validates :doctor, presence: true
    validates :status, length: {maximum: 250}
end
