class PatientsController < ApplicationController
    include SessionsHelper
    
    def index
        user = authenticate_user
        
        @patients = Patient.where("doctor = ?", user.id).order('updated_at DESC')
    end
    
    def show
        user = authenticate_user
        
        @patient = Patient.find_by(["id = :i AND doctor = :d", { i: params[:id], d: user.id }])
        
        if @patient.nil?
            flash[:danger] = "Patient does not exist"
            redirect_to :action => "index"
        end
        
        records = Record.select("start_at", "end_at").where("patient = ?", params[:id]).order("start_at ASC").to_a
        @enabled_dates = []
        records.each do |record|
            date_str = Time.at(record.start_at).to_date.to_s
            if (!@enabled_dates.include?(date_str))
               @enabled_dates.push(date_str)
            end
            date_str = Time.at(record.end_at).to_date.to_s
            if (!@enabled_dates.include?(date_str))
                @enabled_dates.push(date_str)
            end
        end
        
        # added types
        @types = Type.select("id","name").to_a
    end
    
    def new
        @patient = Patient.new
    end
    
    def create
        user = authenticate_user
        
        @patient = Patient.new(patient_params)
        @patient.doctor = user.id
        if @patient.save
            flash[:success] = "You added a patient"
            redirect_to :action => "index"
        else
            flash[:danger] = "Failed to add patient"
            render 'new'
        end
    end
    
    def destroy
        user = authenticate_user
        
        patient = Patient.find_by(["id = :i AND doctor = :d", { i: params[:id], d: user.id }])
        patient.destroy if !patient.nil?
        redirect_to :back
    end
    
    private
    
        def patient_params
            params.require(:patient).permit(:name, :description)
        end

end
