class HttpController < ApplicationController
    # skip_before_filter  :verify_authenticity_token
    require 'date'
    include HttpHelper
    
    @@cache_seconds = 2
    
    protect_from_forgery with: :null_session
    
    def show
        params = fetch_params
        
        if (param_exist?(params, "patient"))
            patient = params[:patient]
            init_time = params[:range]["0"].to_datetime
            end_time = params[:range]["1"].to_datetime
            types = params[:types]
            
            records = Record.select(["start_at", "end_at", "type_id", "data"])
                            .where("patient = ? AND type_id IN (?) AND start_at >= ? AND end_at <= ?", patient, types, init_time, end_time)
                            .order("start_at ASC")
                            .to_a
            if (records.size > 0)
                ret_arr = sample_records(records)
                json_respond(ret_arr)
            else
                ret_arr = []
                types.each do |type|
                    name = Type.select("name").where("id = ?", type).to_a[0]["name"]
                    ret_arr.push({
                        "range": {
                            "start": Time.at(init_time).utc,
                            "end": Time.at(end_time).utc
                        },
                        "data": {
                            "#{name}": "[]"
                        },
                        "sampled": false
                    })
                end
                json_respond(ret_arr)
            end
        end
        
    end
    
    
    def click_update
        params = update_params
        
        patient = params[:patient]
        init_time = (params[:range]["0"].to_time - 10).to_datetime
        end_time = (params[:range]["1"].to_time + 10).to_datetime
        
        type_id = Type.select("id")
                      .where("name = ?", params[:name])
                      .to_a[0]["id"]
        
        records = Record.select("start_at", "end_at", "types.name", "sample_rate", "num_of_samples", "data")
                        .joins('LEFT JOIN types on types.id = records.type_id')
                        .where("patient = ? AND type_id = ? AND start_at >= ? AND end_at <= ?", patient, type_id, init_time, end_time)
                        .order("start_at ASC")
                        .to_a
        
        if (records.nil? || records.empty?)
            json_respond({})
            return
        end
        
        # determine whether data is continuous or discrete
        rec0 = records[0]
        diff_ms = rec0.end_at.to_ms - rec0.start_at.to_ms
        num_of_samples = rec0.num_of_samples
        
        if (diff_ms == 0 && num_of_samples == 1)
            start_ms = records[0].start_at.to_ms
            end_ms = records[records.size - 1].end_at.to_ms
            ret_arr = sample_points(records, params[:option])
            json_respond(ret_arr)
        else
            ret_arr = sample_records(records, params[:option])
            json_respond(ret_arr)
        end

    end
    
    def brush_update
        # need to update all signals being displayed
        params = brush_params
        patient = params[:patient]
        names = params[:names]   # an array of names
        init_time = params[:range]["0"].to_time
        end_time = params[:range]["1"].to_time
        options = params[:options]   # an object array of options
        type_ids = []
        # name maybe an array of names
        names.each do |name|
            type_ids.push(
                type_id = Type.select("id")
                .where("name = ?", name)
                .to_a[0]["id"]
            )
        end
        ret = []
        
        records = Record.select("start_at", "end_at", "types.name", "type_id", "sample_rate", "num_of_samples", "data")
        .joins('LEFT JOIN types on types.id = records.type_id')
        .where("patient = ? AND type_id IN (?) AND start_at >= ? AND end_at <= ?", patient, type_ids, (init_time-10).to_datetime, (end_time+10).to_datetime)
        .order("start_at ASC")
        .to_a
        
        point_records = {}
        data_records = {}
        
        records.each do |rec|
            start_ms = rec.start_at.to_ms
            end_ms = rec.end_at.to_ms
            diff_ms = end_ms - start_ms
            # rec.data = eval(rec.data) // when storing evaluated data it automatically converts it back to string!!
            
            if (diff_ms == 0)
                if (start_ms >= (init_time-@@cache_seconds).to_ms && start_ms <= (end_time+@@cache_seconds).to_ms)
                    if (point_records[rec.name].nil?)
                        point_records[rec.name] = []
                    end
                    point_records[rec.name].push(rec)
                end
            else
                data = eval(rec.data)
                interval = diff_ms / data.size
                count = 0
                tmp = []
                start_at = nil
                for t in (start_ms...end_ms).step(interval) do
                    # clip data points out of range
                    if (t >= (init_time.to_time-@@cache_seconds).to_ms && t < (end_time.to_time+@@cache_seconds).to_ms)
                        if (start_at.nil?)
                            start_at = Time.at(t.to_f / 1000)
                        end
                        tmp.push(data[count])
                    elsif (t >= (end_time.to_time+@@cache_seconds).to_ms)
                        break
                    end
                    count += 1
                end
                end_at = Time.at((start_ms + interval * count).to_f / 1000)
                rec.start_at = start_at
                rec.end_at = end_at
                next if tmp.size == 0
                rec.data = tmp
                if (data_records[rec.name].nil?)
                    data_records[rec.name] = []
                end
                data_records[rec.name].push(rec)
            end
        end
        
        if (!point_records.nil? && !point_records.empty?)
            # determine options and apply operations
            point_records.each do |name, records|
                ret += sample_points(records, options[name])
            end
        end
        
        if (!data_records.nil? && !data_records.empty?)
            data_records.each do |name, records|
                #records[0].start_at = init_time-@@cache_seconds
                #records[records.size-1].end_at = end_time + @@cache_seconds
                ret += sample_records(records, options[name])
            end
        end
        
        json_respond(ret)

    end
    
    
    def new
        @record = Record.new
    end
    
    ## TODO:: none
    def create
        # convert datetime to format acceptable for SQL
        params = record_params
        
        # check for errors
        #if (!param_exist?(params, "patient"))
        #    json_respond({error: "patient id is empty"})
        #    return
        #end
        
        #if (!param_exist?(params, "start_at") || !param_exist?(params, "end_at"))
        #    json_respond({error: "missing field start_at or end_at"})
        #    return
        #end
        
        #if (!param_exist?(params, "ekg_reading") && !param_exist?(params, "blood_pressure"))
        #    json_respond({warning: "both ekg and blood pressure readings are empty"})
        #   return
        #end
        
        params[:start_at] = Time.at(params[:start_at].to_f/1000).utc.to_datetime    # used to_f to correctly parse milliseconds
        params[:end_at] = Time.at(params[:end_at].to_f/1000).utc.to_datetime
        
        if (param_exist?(params, "type_name"))
            params[:type_id] = Type.select("id").where("name = ?", params[:type_name]).to_a[0]["id"]
        end
        params.delete :type_name
        
        @record = Record.new(params)
        
        @record.attributes.each do |attr|
            puts attr
        end
        
        #puts @record.valid?
        #puts @record.errors.messages
        
        if @record.save
            patient_id = @record.patient
            type_name = Type.select("name").where("id = ?", @record.type_id).to_a[0]["name"]
            ret = {
                "range": {
                    "start": @record.start_at,
                    "end": @record.end_at
                },
                "data": {
                    "#{type_name}": @record.data
                },
                "option": "value",
                "sampled": false
            }
            
            # publish to real-time update channel (no message will be sent if no subscriber)
            WebsocketRails[:"update#{patient_id}"].trigger 'new', ret
            
            # send resp code 200 & terminate the action
            head :ok
        else
            json_respond({error: "error saving record"})
        end
    end
    
    private
    def record_params
        params.permit(:patient, :type_id, :type_name, :data, :sample_rate, :num_of_samples, :start_at, :end_at)
    end
    
    def fetch_params
        params.permit(:patient, types: [], range: [:"0", :"1"])
    end
    
    def update_params
        params.permit(:patient, :name, :option, range: [:"0", :"1"])
    end
    
    def brush_params
        params.permit(:patient, names: [], options: [ :ekg_reading, :heart_rate, :blood_pressure ], range: [:"0", :"1"])
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
