class ApplicationController < ActionController::Base
  protect_from_forgery
  layout :layout_by_resource
  def layout_by_resource
    if user_signed_in?
      "application"
    else
      "login"
    end
  end

  rescue_from CanCan::AccessDenied do |exception|
    flash[:alert] = exception.message
    redirect_to home_path
  end
end
