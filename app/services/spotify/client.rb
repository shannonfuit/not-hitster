require "net/http"
require "uri"
require "json"

module Spotify
  class Client
    API_BASE = "https://api.spotify.com/v1".freeze

    def initialize(access_token)
      @access_token = access_token
    end

    # Accepts a full playlist URL or a bare ID; returns enumerator of track items
    def each_playlist_track(playlist_url_or_id, &block)
      return to_enum(__method__, playlist_url_or_id) unless block_given?

      playlist_id = extract_playlist_id(playlist_url_or_id)
      url = URI("#{API_BASE}/playlists/#{playlist_id}/tracks?limit=100")

      while url
        data = get_json(url)
        items = data["items"] || []
        items.each(&block)
        next_url = data["next"]
        url = next_url ? URI(next_url) : nil
      end
    end

    private

    # Handles URLs like:
    # https://open.spotify.com/playlist/<id>
    # spotify:playlist:<id>
    # or just <id>
    def extract_playlist_id(input)
      case input
      when /\Ahttps?:\/\/open\.spotify\.com\/playlist\/([a-zA-Z0-9]+)/
        Regexp.last_match(1)
      when /\Aspotify:playlist:([a-zA-Z0-9]+)\z/
        Regexp.last_match(1)
      else
        input
      end
    end

    def get_json(uri)
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{@access_token}"
      req["Accept"]        = "application/json"
      req["User-Agent"]    = "yourapp-spotify-client/1.0"

      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                      open_timeout: 5, read_timeout: 10) do |http|
        res = http.request(req)
        raise "spotify_error: #{res.code} #{res.body}" unless res.is_a?(Net::HTTPSuccess)
        JSON.parse(res.body)
      end
    end
  end
end
