module Spotify
  class Oauth
    TOKEN_URL = URI("https://accounts.spotify.com/api/token")

    def initialize
      @client_id     = ENV.fetch("SPOTIFY_CLIENT_ID")
      @client_secret = ENV.fetch("SPOTIFY_CLIENT_SECRET")
      @redirect_uri  = ENV.fetch("SPOTIFY_REDIRECT_URI")
    end

    def exchange_code(code)
      post(grant_type: "authorization_code", code:, redirect_uri: @redirect_uri,
          client_id: @client_id, client_secret: @client_secret)
    end

    def refresh(refresh_token)
      post(grant_type: "refresh_token", refresh_token:, client_id: @client_id, client_secret: @client_secret)
    end

    private

    def post(form)
      req = Net::HTTP::Post.new(TOKEN_URL)
      req.set_form_data(form)
      Net::HTTP.start(TOKEN_URL.host, TOKEN_URL.port, use_ssl: true) do |http|
        JSON.parse(http.request(req).body)
      end
    end
  end
end
