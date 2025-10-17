module Spotify
  class AuthorizeUrl
    AUTH_URL = URI("https://accounts.spotify.com/authorize")
    def self.build(state:)
      AUTH_URL.dup.tap do |u|
        u.query = URI.encode_www_form(
          client_id:     ENV.fetch("SPOTIFY_CLIENT_ID"),
          response_type: "code",
          redirect_uri:  ENV.fetch("SPOTIFY_REDIRECT_URI"),
          scope:         ENV.fetch("SPOTIFY_SCOPES"),
          state:,
          show_dialog:   "false"
        )
      end.to_s
    end
  end
end
