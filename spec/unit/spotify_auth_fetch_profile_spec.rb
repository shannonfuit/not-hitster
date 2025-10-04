require "rails_helper"
require "webmock/rspec"

RSpec.describe SpotifyAuthController do
  subject(:controller_instance) { described_class.new }

  let(:url) { "https://api.spotify.com/v1/me" }
  let(:token) { "AT" }

  it "returns parsed JSON on 200" do
    stub_request(:get, url)
      .with(headers: {
        "Authorization" => "Bearer #{token}",
        "Accept" => "application/json"
      })
      .to_return(status: 200, body: { id: "u1" }.to_json, headers: { "Content-Type" => "application/json" })

    result = controller_instance.send(:fetch_profile!, token)
    expect(result).to eq("id" => "u1")
  end

  it "raises SpotifyProfileError on non-200" do
    stub_request(:get, url).to_return(status: 401, body: { error: "bad token" }.to_json)
    expect {
      controller_instance.send(:fetch_profile!, token)
    }.to raise_error(SpotifyAuthController::SpotifyProfileError, /returned 401/)
  end

  it "raises JSON::ParserError on invalid JSON" do
    stub_request(:get, url).to_return(status: 200, body: "not-json")
    expect {
      controller_instance.send(:fetch_profile!, token)
    }.to raise_error(JSON::ParserError)
  end

  it "propagates timeouts" do
    stub_request(:get, url).to_timeout

    expect {
      controller_instance.send(:fetch_profile!, token)
    }.to raise_error(Timeout::Error)
  end

  it "raises on missing token" do
    expect {
      controller_instance.send(:fetch_profile!, nil)
    }.to raise_error(SpotifyAuthController::SpotifyProfileError, /Missing access token/)
  end
end
