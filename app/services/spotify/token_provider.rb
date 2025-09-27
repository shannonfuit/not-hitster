module Spotify
  class TokenProvider
    def initialize(user)
      @user = user
    end

    def access_token!
      raise "not_authenticated" unless @user

      if @user.token_expired?
        tokens = ::Spotify::Oauth.new.refresh(@user.refresh_token)
        raise "refresh_failed" unless tokens&.dig("access_token")

        @user.update!(
          access_token:     tokens["access_token"],
          token_expires_at: Time.current + tokens["expires_in"].to_i.seconds,
          refresh_token:    (tokens["refresh_token"].presence || @user.refresh_token)
        )
      end

      @user.access_token
    end

    def access_token_with_ttl!
      token = access_token!
      expires_in = (@user.token_expires_at - Time.current).to_i
      [ token, expires_in.positive? ? expires_in : 0 ]
    end
  end
end
