class User < ApplicationRecord
  def token_expired?
      token_expires_at.present? && token_expires_at <= Time.current
  end
end