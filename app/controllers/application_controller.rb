class ApplicationController < ActionController::Base
    # Prevent CSRF attacks by raising an exception.
    # For APIs, you may want to use :null_session instead.
    protect_from_forgery with: :exception
    include SessionsHelper

    def authenticate_user
        if logged_in?
            @user = @current_user
        else
            flash.now[:danger] = 'You must log in to perform this action'
            render 'sessions/new'
        end
    end

end
