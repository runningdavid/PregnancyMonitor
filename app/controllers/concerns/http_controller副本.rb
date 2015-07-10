class HttpController < ApplicationController
    #skip_before_filter  :verify_authenticity_token
    require 'date'
    include HttpHelper
    
    protect_from_forgery with: :null_session
    
    @@filter_fields = ["start_at", "end_at", "sample_rate", "num_of_samples", "ekg_reading", "blood_pressure"]
    
    def show
        params = fetch_params
        
        if (param_exist?(params, "patient"))
            
            if (!params.has_key?(:start_time) && !params.has_key?(:stop_time))
                #retrieve ekg first
                type_id = Type.select("id")
                            .where("name = ?", "ekg_reading")
                            .to_a[0]["id"]
                
                record = Record.select(["start_at", "end_at", "data"])
                                .where("patient = ? AND type_id = ?", params[:patient], type_id)
                                .order("start_at DESC")  #fetch the latest data
                                .limit(1)
                                
                ekg_arr = record.to_a
                init_time = ekg_arr[0].start_at.to_datetime
                end_time = ekg_arr[0].end_at.to_datetime
                
                #retrieve blood pressure next
                type_id = Type.select("id")
                                .where("name = ?", "blood_pressure")
                                .to_a[0]["id"]
                                
                record = Record.select(["start_at", "end_at", "data"])
                                .where("patient = ? AND type_id = ? AND start_at >= ? AND end_at <= ?", params[:patient], type_id, init_time, end_time)
                                .order("start_at ASC")  #fetch the latest data
                                
                bp_arr = record.to_a
                
            elsif (exist?(params[:start_time])) #parse start time: used to_f to correctly parse milliseconds
                start_time = Time.at(params[:start_time].to_f/1000).utc.to_datetime
                
                if (!exist?(params[:stop_time]))    #if stop time isn't specified, make it 60 secs after the start time
                    stop_time = start_time + 60
                else    #parse stop time
                    stop_time = Time.at(params[:stop_time].to_f/1000).utc.to_datetime
                end
                
                record = Record.select(@@filter_fields)
                                .where("patient = ? AND start_at BETWEEN ? AND ?", params[:patient], start_time, stop_time)
                                .order("start_at ASC")    #time of data must be in ascending order
            else    #error
                json_respond({error: "start time is nil or empty"})
                return
            end
            
            #if time interval is too long, consider to use subsample algorithms
            sampled = false
            
            data_points = ranges_to_points(ekg_arr[0].data, ekg_arr[0].start_at, ekg_arr[0].end_at)
            sampled_data = LTTB_downsample(data_points, 600)
            if (data_points != sampled_data)
                sampled = true
                ekg_arr[0].data = sampled_data
            end
            
            
            #rec_arr = Array.new
            logger.debug(ekg_arr)
            logger.debug(bp_arr)
            logger.debug(ekg_arr + bp_arr)
            
            rec_arr = ekg_arr + bp_arr
            
            #data_points = ranges_to_points(rec_arr[0].blood_pressure, rec_arr[0].start_at, rec_arr[0].end_at)
            #sampled_data = LTTB_downsample(data_points, 600)
            #if (data_points != sampled_data)
            #    sampled = true
            #    rec_arr[0].blood_pressure = sampled_data
            #end
            #!!!set downsample to true if downsampled!!!
            
            #reformat data to make it easier to use
            ret_arr = Array.new
            rec_arr.each do |rec|
                datum = { "range":
                            { "start": rec.start_at, "end": rec.end_at },
                          "data":
                            {  },
                          "downsampled":
                            sampled,
                          "sample_rate":
                            rec.sample_rate,
                          "num_of_samples":
                            rec.num_of_samples
                        }
                rec.attributes.each_pair do |name, value|
                    if (!["start_at", "end_at", "sample_rate", "num_of_samples", "id"].include?(name))
                        datum[:data][name] = value
                    end
                end
                
                ret_arr.push(datum)
            end
            
            #return record data
            json_respond(ret_arr)
            return
        
        else    #error
            json_respond({error: "patient id is not specified"})
            return
        end
        
    end
    
    def click_update
        params = click_update_params
        record = Record.select("start_at", "end_at", "sample_rate", "num_of_samples", params[:name])
            .where("patient = ? AND start_at >= ? AND end_at <= ?", params[:patient], params[:range]["0"].to_datetime, params[:range]["1"].to_datetime)
            .not(ekg_reading: nil)
            .order("start_at ASC")    #time of data must be in ascending order
        
        rec_arr = record.to_a
        
        case params[:option]
        when "value"
            puts 0
        when "average"
            rec_arr.each do |rec|
                rec[params[:name]] = average_downsample(rec[params[:name]], 500)
            end
        when "peak-to-peak"
            puts 2
        when "min-max"
            puts 3
        end
        
        json_respond(rec_arr)

    end
    
    def brush_update
        
    end
    
    
    def new
        @record = Record.new
    end
    
    def create
        #convert datetime to format acceptable for SQL
        params = record_params
        
        #check for errors
        if (!param_exist?(params, "patient"))
            json_respond({error: "patient id is empty"})
            return
        end
        
        if (!param_exist?(params, "start_at") || !param_exist?(params, "end_at"))
            json_respond({error: "missing field start_at or end_at"})
            return
        end
        
        if (!param_exist?(params, "ekg_reading") && !param_exist?(params, "blood_pressure"))
            json_respond({warning: "both ekg and blood pressure readings are empty"})
            return
        end
        
        params[:start_at] = Time.at(params[:start_at].to_f/1000).utc.to_datetime    #used to_f to correctly parse milliseconds
        params[:end_at] = Time.at(params[:end_at].to_f/1000).utc.to_datetime
        
        @record = Record.new(params)
        if @record.save
            patient_id = @record.patient
            
            #filter out unnecessary fields and build an object array for websocket
            @json = "[" + @record.to_json(:only => @@filter_fields) + "]"
            
            #publish to real-time update channel (no message will be sent if no subscriber)
            WebsocketRails[:"update#{patient_id}"].trigger 'new', @json
            
            #send resp code 200 & terminate the action
            head :ok
        else
            json_respond({error: "record saving error"})
        end
    end
    
    private
    
    def record_params
        params.permit(:patient, :ekg_reading, :blood_pressure, :start_at, :end_at)
    end
    
    def fetch_params
        params.permit(:patient, :start_time, :stop_time)
    end
    
    def click_update_params
        params.permit(:patient, :name, :option, range: [:"0", :"1"])
    end
    
    def exist?(var)
        !var.nil? && !var.empty?
    end
    
    def param_exist?(params, field)
        params.has_key?(:"#{field}") && exist?(params[:"#{field}"])
    end
    
    def json_respond(msg)
        respond_to do |format|
            format.json {
                render :json => msg
            }
        end
    end
    
end
