class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  helper_method :current_user, :user_signed_in?

  before_action :require_sign_in
  before_action :set_sentry_user

  def set_sentry_user
    return unless current_user

    Sentry.set_user(
      id: current_user.id,
      display_name: current_user.display_name,
      email: current_user.email
    )
  end

  def require_sign_in
    redirect_to sign_in_path unless user_signed_in?
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def user_signed_in?
    current_user.present?
  end
end
