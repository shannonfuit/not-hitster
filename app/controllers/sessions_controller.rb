class SessionsController < ApplicationController
  skip_before_action :require_sign_in, only: %i[new]

  def new
    redirect_to root_path if user_signed_in?
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out."
  end
end
