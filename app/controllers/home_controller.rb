class HomeController < ApplicationController
  before_action :require_sign_in

  def index
  end

  def require_sign_in
    redirect_to sign_in_path unless user_signed_in?
  end
end
