module HttpHelper
    
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
    
    @@threshold = 1000
    @@cache_seconds = 2
    
    def sample_records(records, option = "value")
        ret_arr = []
        
        if (option == "value")
            sizes = {}
            
            records.each do |rec|
                data = rec.data
                if (data.class == String)   # use regex to determine whether it's an array in string
                    data = eval(data)
                end
                
                if (sizes[rec.type_id].nil?)
                    sizes[rec.type_id] = data.size
                else
                    sizes[rec.type_id] += data.size
                end
            end
            
            records.each do |rec|
                sampled = false
                
                if (sizes[rec.type_id] > @@threshold)
                    points = ranges_to_points(rec.data, rec.start_at, rec.end_at)
                    factor = @@threshold.to_f / sizes[rec.type_id]
                    rec.data = LTTB_downsample(points, (eval(rec.data).size * factor).floor)
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
            
            return ret_arr
        else
        
            # determine time range and choose the sample rate
            # TODO:: (maybe) each reading should correspond to precisely the start of a time period
            records.each do |rec|
                diff_ms = rec.end_at.to_ms - rec.start_at.to_ms
                next if (diff_ms == 0)
                sample_rate = rec.sample_rate.to_i
                rec.data = sample_data(rec.data, diff_ms, sample_rate, option)
                
            end
            
            ret_arr = []
            records.each do |rec|
                ret = {
                    "range": {
                        "start": rec.start_at,
                        "end": rec.end_at
                    },
                    "data": {
                        "#{rec.name}": rec.data
                    },
                    "option": option,
                    "sampled": false
                }
                
                ret_arr.push(ret)
            end
            
            return ret_arr
        end
        
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
    
    def sample_points(records, option = "value")
        if (option == "value")
            # fill in here
            tmp = []
            records.each do |rec|
                # no need to clip data since discrete points must be in range
                tmp.push([Time.at(rec.start_at).to_ms,eval(rec.data)[0].to_f])
            end
            data = LTTB_downsample(tmp, @@threshold, true)
            
            ret = []
            data.each do |datum|
                ret.push({
                    "range": {
                        "start": Time.at(datum[0].to_f/1000).utc,    # !!need to round to minutes, not seconds!!
                        "end": Time.at(datum[0].to_f/1000).utc
                    },
                    "data": {
                        "#{records[0].name}": [datum[1]].to_json
                    },
                    "option": "value",
                    "sampled": false
                })
            end
            return ret
        end
        
        # no need to sort since date is ASC when data is fetched
        start_ms = records[0].start_at.to_ms
        end_ms = records[records.size - 1].end_at.to_ms
        diff_ms = end_ms - start_ms
        
        if (diff_ms <= @@time_constants[:minute])
            # just take the average of minute
            #arr = []
            #records.each do |rec|
            #    arr.push(rec.data.to_f)
            #end
            #
            #return downsample(arr, arr.size, option)
            interval = @@time_constants[:minute]
            return _sample_helper_(records, start_ms, end_ms, interval, option)
            
            elsif (diff_ms <= @@time_constants[:hour])
            # sample by minutes
            interval = @@time_constants[:minute]
            return _sample_helper_(records, start_ms, end_ms, interval, option)
            
            elsif (diff_ms <= @@time_constants[:day])
            # sample by hours
            interval = @@time_constants[:hour]
            return _sample_helper_(records, start_ms, end_ms, interval, option)
            
            elsif (diff_ms <= @@time_constants[:week])
            # sample by days
            interval = @@time_constants[:day]
            return _sample_helper_(records, start_ms, end_ms, interval, option)
            
            elsif (diff_ms <= @@time_constants[:month])
            # sample by days
            interval = @@time_constants[:day]
            return _sample_helper_(records, start_ms, end_ms, interval, option)
            
            elsif (diff_ms <= @@time_constants[:year])
            # sample by months
            interval = @@time_constants[:month]
            return _sample_helper_(records, start_ms, end_ms, interval, option)
            
            else
            # sample by months
            interval = @@time_constants[:month]
            return _sample_helper_(records, start_ms, end_ms, interval, option)
            
        end
    end
    
    def _sample_helper_(records, start_ms, end_ms, interval, option = "value")
        ret = []
        
        for t in (start_ms...end_ms).step(interval) do  # triple dots exclude end_ms from range
            tmp = []
            records.each do |rec|
                if (rec.start_at.to_ms >= t && rec.end_at.to_ms < t + interval)
                    tmp.push(eval(rec.data)[0].to_f)
                    #else
                    #break
                end
            end
            #ret.push(downsample(tmp, tmp.size, option))
            if (tmp.size > 0)
                #average = (tmp.inject{|sum,x| sum + x }) / tmp.size
                #average = average.round(3)
                value = downsample(tmp, tmp.size, option)[0]    # downsample methods return arrays (even though they only contain 1 value)
                
                data = {
                    "range": {
                        "start": Time.zone.at(t / 1000),    # !!need to round to minutes, not seconds!!
                        "end": Time.zone.at((t+interval) / 1000)
                    },
                    "data": {
                        "#{records[0].name}": [value, value].to_json
                    },
                    "option": option,
                    "sampled": false
                }
                
                ret.push(data)
            end
        end
        
        return ret
    end
    
    # convert data over a time range to data points for down sampling
    # data: an array of points
    # @start_time: time stamp
    # @stop_time: time stamp
    def ranges_to_points(data, start_time, stop_time)
        # if passed in a string, convert it into array
        if (data.class == String)
            data = eval(data)
        end
        
        # helper method to handle milliseconds
        # extends the Time class
        start_ms = Time.at(start_time).to_ms
        stop_ms = Time.at(stop_time).to_ms
        interval = (stop_ms - start_ms) / data.size
        
        count = 0
        @ret_arr = Array.new
        for i in (start_ms..stop_ms-interval).step(interval) do
           @ret_arr.push([i, data[count]])
           count += 1
        end

        @ret_arr
    end
    
    
    # largest triangle three buckets algorithm
    # @data: an array of tuples (x & y points); datetime need to be converted to timestamp values
    # @threshold: number of data points returned after sampling
    # @pair: push pairs of time-value to the return array or push values only
    def LTTB_downsample(data, threshold = 0, pair = false)
        data_size = data.size
        sampled_data = Array.new
        nextA = 0
        
        if (threshold >= data_size || threshold == 0)
            # safety backup code
            # get rid of time
            if (!pair)
                tmp = []
                data.each do |datum|
                   tmp.push(datum[1])
                end
                
                data = tmp
            end
            return data
        end
        
        bucket_size = (data_size - 2).to_f / (threshold - 2) # leave room for the first and the last data point
        
        a = 0
        pair ? sampled_data.push(data[a]) : sampled_data.push(data[a][1])  # select the point in the first bucket
        
        # for each bucket except the first and last do
        # for loop equal to for (i = 0; i <= threshold-3; i++)
        for i in 0..threshold-3 do
            # calculate point average for next bucket
            range_start = ((i+1) * bucket_size).floor + 1
            range_end = (range_start + bucket_size).floor
            
            range_end = range_end < data_size ? range_end : data_size - 1
            range = range_end > range_start ? range_end - range_start : 1   # make size of last bucket 1 instead of 0 (which will result in a zero division error)
            
            avgX = 0
            avgY = 0
            
            for j in range_start..range_end do
                avgX += data[j][0]    # must be a number
                avgY += data[j][1]    # must be a number
            end
            
            avgX /= range
            avgY /= range
            
            # get range of this bucket
            range_offs = ((i+0) * bucket_size).floor + 1
            range_to = (range_offs + bucket_size).floor
            
            pointAx = data[a][0]    # need work
            pointAy = data[a][1]
            
            maxArea = -1
            
            for j in range_offs..range_to do
                area = ((pointAx - avgX) * (data[j][1] - pointAy) - (pointAx - data[j][0]) * (avgY - pointAy)).abs * 0.5
                
                if (area > maxArea)
                    maxArea = area
                    pair ? maxAreaPoint = data[j] : maxAreaPoint = data[j][1]
                    nextA = j
                end
            end
            
            sampled_data.push(maxAreaPoint)
            a = nextA
        end
            
        pair ? sampled_data.push(data[data_size - 1]) : sampled_data.push(data[data_size - 1][1])  # push the last bucket
            
        return sampled_data
    end
    
    # only works well if (data / threshold > 1)
    def average_downsample(data, bucket_size)
        if (data.class == String)
            data = eval(data)
        end
        
        if (bucket_size == 0 || bucket_size == 1)
            return data
        end
    
        data = data.each_slice(bucket_size).to_a
        ret = Array.new
        
        data.each do |arr|
            mean = (arr.inject{ |sum, el| sum + el }.to_f / arr.size).round(3)
            ret.push(mean)
        end
        
        return ret
    end
    
    
    def min_max_downsample(data, bucket_size)
        if (data.class == String)
            data = eval(data)
        end
    
        if (bucket_size == 0 || bucket_size == 1)
            return data
        end
        
        data = data.each_slice(bucket_size).to_a
        ret = Array.new
        
        data.each do |arr|
            peaks = arr.minmax
            ret.push(peaks)
        end
        
        return ret
    end
    
    # only works well if (data / threshold > 1)
    def peak_to_peak_downsample(data, bucket_size)
        if (data.class == String)
            data = eval(data)
        end
        
        if (bucket_size == 0 || bucket_size == 1)
            return data
        end
        
        data = data.each_slice(bucket_size).to_a
        ret = Array.new
        
        data.each do |arr|
            peak_to_peak = (arr.max - arr.min).round(3)
            ret.push(peak_to_peak)
        end
        
        return ret
    end
    
    
    def subsample   # include nth point only
        
    end
        

end
