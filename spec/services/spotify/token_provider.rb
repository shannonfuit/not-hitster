require "rails_helper"

RSpec.describe Spotify::TokenProvider do
  let(:now)  { Time.zone.parse("2025-01-01 12:00:00") }
  let(:user) { instance_double("User") }

  before do
    allow(Time).to receive(:current).and_return(now)
  end

  describe "#access_token!" do
    it "raises when no user is provided" do
      expect { described_class.new(nil).access_token! }
        .to raise_error("not_authenticated")
    end

    context "when the user's token is not expired" do
      it "returns the existing access_token and does not call refresh" do
        allow(user).to receive(:token_expired?).and_return(false)
        allow(user).to receive(:access_token).and_return("cached_access_token")

        expect(::Spotify::Oauth).not_to receive(:new)

        token = described_class.new(user).access_token!
        expect(token).to eq("cached_access_token")
      end
    end

    context "when the user's token is expired" do
      let(:oauth) { instance_double("Spotify::Oauth") }

      before do
        allow(user).to receive(:token_expired?).and_return(true)
        allow(user).to receive(:refresh_token).and_return("old_refresh_token")
        allow(::Spotify::Oauth).to receive(:new).and_return(oauth)
      end

      it "refreshes, updates the user, and returns the new access_token" do
        tokens = { "access_token" => "new_access_token", "expires_in" => 7200, "refresh_token" => "new_refresh_token" }
        expect(oauth).to receive(:refresh).with("old_refresh_token").and_return(tokens)

        expect(user).to receive(:update!).with(
          access_token:     "new_access_token",
          token_expires_at: now + 7200.seconds,
          refresh_token:    "new_refresh_token"
        ) do
          allow(user).to receive(:access_token).and_return("new_access_token")
          allow(user).to receive(:token_expires_at).and_return(now + 7200.seconds)
          allow(user).to receive(:refresh_token).and_return("new_refresh_token")
        end

        token = described_class.new(user).access_token!
        expect(token).to eq("new_access_token")
      end

      it "keeps the old refresh_token if the response doesn't include one" do
        tokens = { "access_token" => "new_access_token", "expires_in" => 3600, "refresh_token" => nil }
        expect(oauth).to receive(:refresh).with("old_refresh_token").and_return(tokens)

        expect(user).to receive(:update!).with(
          access_token:     "new_access_token",
          token_expires_at: now + 3600.seconds,
          refresh_token:    "old_refresh_token"
        ) do
          allow(user).to receive(:access_token).and_return("new_access_token")
          allow(user).to receive(:token_expires_at).and_return(now + 3600.seconds)
          allow(user).to receive(:refresh_token).and_return("old_refresh_token")
        end

        token = described_class.new(user).access_token!
        expect(token).to eq("new_access_token")
      end

      it "raises when refresh fails or returns no access_token" do
        expect(oauth).to receive(:refresh).with("old_refresh_token").and_return({ "expires_in" => 3600 })

        expect(user).not_to receive(:update!)
        expect {
          described_class.new(user).access_token!
        }.to raise_error("refresh_failed")
      end
    end
  end

  describe "#access_token_with_ttl!" do
    context "when token is valid (not expired)" do
      it "returns [access_token, ttl_in_seconds]" do
        allow(user).to receive(:token_expired?).and_return(false)
        allow(user).to receive(:access_token).and_return("cached_access_token")
        allow(user).to receive(:token_expires_at).and_return(now + 1800.seconds) # 30 min left

        token, ttl = described_class.new(user).access_token_with_ttl!
        expect(token).to eq("cached_access_token")
        expect(ttl).to eq(1800)
      end
    end

    context "when token is expired and gets refreshed" do
      let(:oauth) { instance_double("Spotify::Oauth") }

      it "returns the refreshed token and computed ttl (non-negative)" do
        allow(user).to receive(:token_expired?).and_return(true)
        allow(user).to receive(:refresh_token).and_return("old_refresh_token")
        allow(::Spotify::Oauth).to receive(:new).and_return(oauth)

        tokens = { "access_token" => "new_access_token", "expires_in" => 5, "refresh_token" => "new_refresh_token" }
        expect(oauth).to receive(:refresh).with("old_refresh_token").and_return(tokens)

        expect(user).to receive(:update!).with(
          access_token:     "new_access_token",
          token_expires_at: now + 5.seconds,
          refresh_token:    "new_refresh_token"
        ) do
          allow(user).to receive(:access_token).and_return("new_access_token")
          allow(user).to receive(:token_expires_at).and_return(now + 5.seconds)
          allow(user).to receive(:refresh_token).and_return("new_refresh_token")
        end

        token, ttl = described_class.new(user).access_token_with_ttl!
        expect(token).to eq("new_access_token")
        expect(ttl).to eq(5)
      end
    end

    context "when token_expires_at is in the past" do
      it "clamps TTL at 0" do
        allow(user).to receive(:token_expired?).and_return(false)
        allow(user).to receive(:access_token).and_return("cached_access_token")
        allow(user).to receive(:token_expires_at).and_return(now - 10.seconds)

        token, ttl = described_class.new(user).access_token_with_ttl!
        expect(token).to eq("cached_access_token")
        expect(ttl).to eq(0)
      end
    end
  end
end
