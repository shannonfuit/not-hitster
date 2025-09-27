# spec/services/spotify/client_spec.rb
require "rails_helper"
require "webmock/rspec"

RSpec.describe Spotify::Client do
  let(:access_token) { "test_token" }
  let(:client)       { described_class.new(access_token) }
  let(:playlist_id)  { "PL123ABC" }

  def first_page_url(id = playlist_id)
    "https://api.spotify.com/v1/playlists/#{id}/tracks?limit=100"
  end

  let(:default_headers) do
    {
      "Authorization" => "Bearer #{access_token}",
      "Accept"        => "application/json",
      "User-Agent"    => "yourapp-spotify-client/1.0"
    }
  end

  describe "#each_playlist_track" do
    context "enumeration & pagination" do
      it "returns an Enumerator when no block is given and enumerates across pages" do
        page1 = {
          items: [
            { "track" => { "id" => "t1" } },
            { "track" => { "id" => "t2" } }
          ],
          next: "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks?offset=100&limit=100"
        }.to_json

        page2 = {
          items: [
            { "track" => { "id" => "t3" } }
          ],
          next: nil
        }.to_json

        stub_request(:get, first_page_url)
          .with(headers: default_headers)
          .to_return(status: 200, body: page1)

        stub_request(:get, "https://api.spotify.com/v1/playlists/#{playlist_id}/tracks?offset=100&limit=100")
          .with(headers: default_headers)
          .to_return(status: 200, body: page2)

        enum = client.each_playlist_track(playlist_id)
        expect(enum).to be_a(Enumerator)
        expect(enum.map { |i| i.dig("track", "id") }).to eq(%w[t1 t2 t3])
      end

      it "yields nothing when items are missing/empty" do
        stub_request(:get, first_page_url)
          .with(headers: default_headers)
          .to_return(status: 200, body: { next: nil }.to_json)

        yielded = []
        client.each_playlist_track(playlist_id) { |i| yielded << i }
        expect(yielded).to be_empty
      end
    end

    context "playlist id extraction" do
      it "accepts a bare id" do
        stub_request(:get, first_page_url)
          .to_return(status: 200, body: { items: [], next: nil }.to_json)

        client.each_playlist_track(playlist_id) { |_| }
        expect(a_request(:get, first_page_url)).to have_been_made.once
      end

      it "accepts a https open.spotify.com playlist URL (with query)" do
        input = "https://open.spotify.com/playlist/#{playlist_id}?si=abc"

        stub_request(:get, first_page_url)
          .to_return(status: 200, body: { items: [], next: nil }.to_json)

        client.each_playlist_track(input) { |_| }
        expect(a_request(:get, first_page_url)).to have_been_made.once
      end

      it "accepts a spotify:playlist:<id> URI" do
        input = "spotify:playlist:#{playlist_id}"

        stub_request(:get, first_page_url)
          .to_return(status: 200, body: { items: [], next: nil }.to_json)

        client.each_playlist_track(input) { |_| }
        expect(a_request(:get, first_page_url)).to have_been_made.once
      end
    end

    context "headers & auth" do
      it "sends Authorization, Accept, and User-Agent headers" do
        stub_request(:get, first_page_url)
          .with(headers: default_headers)
          .to_return(status: 200, body: { items: [], next: nil }.to_json)

        client.each_playlist_track(playlist_id) { |_| }

        expect(a_request(:get, first_page_url)
          .with(headers: default_headers)).to have_been_made.once
      end
    end

    context "errors & timeouts" do
      it "raises with status and body on non-success" do
        stub_request(:get, first_page_url)
          .to_return(status: 401, body: { error: "unauthorized" }.to_json)

        expect {
          client.each_playlist_track(playlist_id) { |_| }
        }.to raise_error(RuntimeError, /spotify_error:\s+401\s+/)
      end

      it "propagates timeouts from Net::HTTP" do
        stub_request(:get, first_page_url).to_timeout
        expect {
          client.each_playlist_track(playlist_id) { |_| }
        }.to raise_error { |e|
          expect(e).to be_a(Timeout::Error).or have_message(/execution expired/)
        }
      end

      it "yields items from earlier pages, then raises if a later page fails" do
        page1 = {
          items: [ { "track" => { "id" => "t1" } } ],
          next: "#{first_page_url}&offset=100"
        }.to_json

        stub_request(:get, first_page_url).to_return(status: 200, body: page1)
        stub_request(:get, "#{first_page_url}&offset=100").to_return(status: 500, body: '{"error":"boom"}')

        yielded = []
        expect {
          client.each_playlist_track(playlist_id) { |i| yielded << i }
        }.to raise_error(/spotify_error:\s+500/)

        expect(yielded.map { |i| i.dig("track", "id") }).to eq(%w[t1])
      end
    end
  end
end
