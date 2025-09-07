require "rails_helper"

RSpec.describe Spotify::AuthorizeUrl do
  describe ".build" do
    it "produces a proper Spotify authorize URL including state and env vars" do
      url   = described_class.build(state: "abc123")
      uri   = URI(url)
      query = Rack::Utils.parse_nested_query(uri.query)

      expect(uri.scheme).to eq("https")
      expect(uri.host).to eq("accounts.spotify.com")
      expect(query["client_id"]).to eq(ENV.fetch("SPOTIFY_CLIENT_ID"))
      expect(query["response_type"]).to eq("code")
      expect(query["redirect_uri"]).to eq(ENV.fetch("SPOTIFY_REDIRECT_URI"))
      expect(query["scope"]).to eq(ENV.fetch("SPOTIFY_SCOPES"))
      expect(query["state"]).to eq("abc123")
    end
  end
end
