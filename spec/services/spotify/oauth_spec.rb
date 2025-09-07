require "rails_helper"

RSpec.describe Spotify::Oauth do
  include HttpStub

  let(:service) { described_class.new }

  describe "#exchange_code" do
    it "returns parsed JSON with tokens" do
      json = { access_token: "AT", refresh_token: "RT", expires_in: 3600 }.to_json
      with_http_stub(json) do
        res = service.exchange_code("the-code")
        expect(res["access_token"]).to eq("AT")
        expect(res["refresh_token"]).to eq("RT")
        expect(res["expires_in"]).to eq(3600)
      end
    end
  end

  describe "#refresh" do
    it "returns parsed JSON with new access token" do
      json = { access_token: "NEW_AT", expires_in: 3600 }.to_json
      with_http_stub(json) do
        res = service.refresh("the-refresh")
        expect(res["access_token"]).to eq("NEW_AT")
      end
    end
  end
end
