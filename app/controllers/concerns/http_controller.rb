class HttpController < ApplicationController
    # skip_before_filter  :verify_authenticity_token
    require 'date'
    include HttpHelper
    
    protect_from_forgery with: :null_session
    
    # in ms
    @@time_constants = {
        "year": 31556900000,
        "month": 2629740000,
        "week": 604800000,
        "day": 86400000,
        "hour": 3600000,
        "minute": 60000,
        "second": 1000
    }
    
    @@filter_fields = ["start_at", "end_at", "sample_rate", "num_of_samples", "ekg_reading", "blood_pressure"]
    
    def show
        params = fetch_params
        
        if (param_exist?(params, "patient"))
            init_time = Time.at(1434398920).to_datetime
            end_time = Time.at(1434398925).to_datetime
            
            records = Record.select(["start_at", "end_at", "type_id", "data"])
                            .where("patient = ? AND start_at >= ? AND end_at <= ?", params[:patient], init_time, end_time)
                            .order("start_at ASC")
                            .to_a
            
            ret_arr = Array.new
            sizes = {}  # [type_id, size] pair
            
            records.each do |rec|
                if (sizes[rec.type_id].nil?)
                    sizes[rec.type_id] = rec.data.size
                else
                    sizes[rec.type_id] += rec.data.size
                end
            end
            
            records.each do |rec|
                sampled = false
                
                if (sizes[rec.type_id] > 1000)
                    points = ranges_to_points(rec.data, rec.start_at, rec.end_at)
                    factor = 1000.to_f / sizes[rec.type_id]
                    rec.data = LTTB_downsample(points, (rec.data.size * factor).floor)
                    sampled = true
                end
                
                type_id = rec.type_id
                name = Type.select("name")
                            .where("id = ?", type_id)
                            .to_a[0]["name"]
                
                ret = {
                    "range": {
                        "start": rec.start_at,
                        "end": rec.end_at
                    },
                    "data": {
                        "#{name}": rec.data
                    },
                    "sampled": sampled
                }
               
               ret_arr.push(ret)
            end
            
            json_respond(ret_arr)
        end
            
    end
    
    
    def click_update
        params = click_update_params
        
        patient = params[:patient]
        init_time = params[:range]["0"].to_datetime
        end_time = params[:range]["1"].to_datetime
        
        type_id = Type.select("id")
                      .where("name = ?", params[:name])
                      .to_a[0]["id"]
        
        records = Record.select("start_at", "end_at", "types.name", "sample_rate", "num_of_samples", "data")
                        .joins('LEFT JOIN types on types.id = records.type_id')
                        .where("patient = ? AND type_id = ? AND start_at >= ? AND end_at <= ?", patient, type_id, init_time, end_time)
                        .order("start_at ASC")
                        .to_a
        
        points = {}
        # traverse the records first time to get discrete data points (those with only 1 sample)
        records.delete_if do |rec|
           diff_ms = rec.end_at.to_ms - rec.start_at.to_ms
           num_of_samples = rec.num_of_samples
           name = rec.name
           
           if (diff_ms == 0 && num_of_samples == 1)
               if (points[name].nil?)
                   points[name] = Array.new
               end
                   points[name].push(rec)
               true
           end
        end
        
        # determine time range and choose the sample rate
        # TODO:: (maybe) each reading should correspond to precisely the start of a time period
        records.each do |rec|
           diff_ms = rec.end_at.to_ms - rec.start_at.to_ms
           next if (diff_ms == 0)
           
           sample_rate = rec.sample_rate.to_i
           option = params[:option]
           
           rec.data = sample_data(rec.data, diff_ms, sample_rate, option)
           
        end
        
        # process discrete data points (order should be ascending datetime)
        sampled_points = sample_points(points)
        
        ret_arr = Array.new
        records.each do |rec|
            ret = {
                "range": {
                    "start": rec.start_at,
                    "end": rec.end_at
                },
                "data": {
                    "#{rec.name}": rec.data
                },
                "option": params[:option],
                "sampled": false
            }
            
            ret_arr.push(ret)
        end
        
        # remove blood pressure data from records and put them into a separate array. compute the average values separately. then return
        
        json_respond(ret_arr)

    end
    
    def brush_update
        
    end
    
    
    def new
        @record = Record.new
    end
    
    def create
        # convert datetime to format acceptable for SQL
        params = record_params
        
        # check for errors
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
        
        params[:start_at] = Time.at(params[:start_at].to_f/1000).utc.to_datetime    # used to_f to correctly parse milliseconds
        params[:end_at] = Time.at(params[:end_at].to_f/1000).utc.to_datetime
        
        @record = Record.new(params)
        if @record.save
            patient_id = @record.patient
            
            # filter out unnecessary fields and build an object array for websocket
            @json = "[" + @record.to_json(:only => @@filter_fields) + "]"
            
            # publish to real-time update channel (no message will be sent if no subscriber)
            WebsocketRails[:"update#{patient_id}"].trigger 'new', @json
            
            # send resp code 200 & terminate the action
            head :ok
        else
            json_respond({error: "record saving error"})
        end
    end
    
    private
    
    def sample_points(points)
    
    end
    
    def sample_data(data, diff_ms, sample_rate, option)
        
        if (diff_ms <= @@time_constants[:minute])
            # sample by seconds
            data = downsample(data, sample_rate, option)
        elsif (diff_ms <= @@time_constants[:hour])
            # sample by minutes
            data = downsample(data, sample_rate * 60, option)
        elsif (diff_ms <= @@time_constants[:day])
            # sample by hours
            data = downsample(data, sample_rate * 60 * 60, option)
        elsif (diff_ms <= @@time_constants[:week])
            # sample by days
            data = downsample(data, sample_rate * 60 * 60 * 24, option)
        elsif (diff_ms <= @@time_constants[:month])
            # sample by days
            data = downsample(data, sample_rate * 60 * 60 * 24, option)
        elsif (diff_ms <= @@time_constants[:year])
            # sample by months
            data = downsample(data, sample_rate * 60 * 60 * 24 * 30, option)
        else
            # sample by months
            data = downsample(data, sample_rate * 60 * 60 * 24 * 30, option)
        end
        
        return data

    end
    
    def downsample(data, bucket_size, option)
        case option
        when "average"
            return average_downsample(data, bucket_size)
            
        when "peak-to-peak"
            return peak_to_peak_downsample(data, bucket_size)
            
        when "min-max"
            return min_max_downsample(data, bucket_size)
            
        else
            return {error: "option is missing or wrong option param"}
        end
    end
    
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
