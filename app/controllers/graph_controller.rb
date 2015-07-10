class GraphController < ApplicationController
    include SessionsHelper
    
    def index
        if logged_in?
            
            latest_post = [
            {"start_at":"1974-09-01T10:30:00.000Z","end_at":"1974-09-01T10:40:00.000Z", "ekg_reading":"10,9,8,7,6,5,4,3,2,1", "blood_pressure":"11,11,11,11,11,11,11,11,11,11"},
            {"start_at":"1974-09-01T10:50:00.000Z","end_at":"1974-09-01T11:00:00.000Z", "ekg_reading":"1,2,3,4,5,6,7,8,9,10", "blood_pressure":"11,11,11,11,11,11,11,11,11,11"}
            ].to_json
            
            pid = 12
            logger.debug("update#{pid}")
            WebsocketRails[:"update#{pid}"].trigger 'new', latest_post
            
            render :text => "succeeded"
            
        end
    end
    
    def data
        respond_to do |format|
            format.json {
                render :json => [
                {"start_at":"1974-09-01T09:30:00.000Z","end_at":"1974-09-01T09:30:10.000Z", "ekg_reading":"56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42,56, 37, 29, 67, 76, 82, 77, 42", "blood_pressure":"100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100,100"},
                {"start_at":"1974-09-01T09:30:15.000Z","end_at":"1974-09-01T09:30:16.000Z", "ekg_reading":"56, 37, 29, 67, 76, 82, 77, 42", "blood_pressure":"100,100,100,100,100,100,100,100,100,100"}
                ]
            }
        end
    end

=begin
    def data
        respond_to do |format|
            format.json {
                render :json => [
                {"date":"19740901T09:30:00.00Z", "EKG":7, "Blood Pressure":140},
                {"date":"19740902T09:30:00.00Z", "EKG":8, "Blood Pressure":140},
                {"date":"19740903T09:30:00.01Z", "EKG":9, "Blood Pressure":140},
                {"date":"19740904T09:30:00.01Z", "EKG":10, "Blood Pressure":140},
                {"date":"19740905T09:30:00.02Z", "EKG":11, "Blood Pressure":140},
                {"date":"19740907T09:30:00.02Z", "EKG":20, "Blood Pressure":140}
                ]
            }
        end
    end


    def realdata
        respond_to do |format|
            format.json {
                render :json => [
                {"start":"19740901T09:30:00.00Z","end":"19740901T09:40:00.00Z", "EKG":"[1,2,3,4,5,6,7,8,9,10]", "Blood Pressure":"[11,11,11,11,11,11,11,11,11,11]"},
                {"start":"19740901T09:50:00.00Z","end":"19740901T10:00:00.00Z", "EKG":"[1,2,3,4,5,6,7,8,9,10]", "Blood Pressure":"[11,11,11,11,11,11,11,11,11,11]"}
                ]
            }
        end
    end
=end

end
