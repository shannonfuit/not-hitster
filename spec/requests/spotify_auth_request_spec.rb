require "rails_helper"

RSpec.describe "SpotifyAuth", type: :request do
  def perform_spotify_sign_in(profile_overrides: {}, tokens_overrides: {})
    allow(SecureRandom).to receive(:hex).and_return("fixedstate")
    get spotify_login_path
    expect(session[:spotify_state]).to eq("fixedstate")

    oauth = instance_double("Spotify::Oauth")
    allow(Spotify::Oauth).to receive(:new).and_return(oauth)
    allow(oauth).to receive(:exchange_code).with("ok").and_return(
      { "access_token" => "AT", "refresh_token" => "RT", "expires_in" => 3600 }
        .merge(tokens_overrides.stringify_keys)
    )

    allow_any_instance_of(SpotifyAuthController).to receive(:fetch_profile!).and_return(
      {
        "id" => "spotify-uid",
        "display_name" => "DJ Test",
        "email" => "dj@example.com",
        "images" => [ { "url" => "http://img" } ]
      }.merge(profile_overrides)
    )

    get spotify_callback_path, params: { state: "fixedstate", code: "ok" }
    expect(response).to redirect_to(root_path)
    expect(flash[:notice]).to match(/Signed in with Spotify/i)

    User.find_by!(spotify_uid: profile_overrides.fetch("id", "spotify-uid"))
  end

  describe "GET /auth/spotify" do
    it "redirects to Spotify and stores state in session" do
      allow(SecureRandom).to receive(:hex).and_return("fixedstate")
      get spotify_login_path
      expect(response).to have_http_status(:redirect)
      expect(session[:spotify_state]).to eq("fixedstate")
      expect(response.location).to match(%r{\Ahttps://accounts\.spotify\.com/authorize\?})
    end
  end

  describe "GET /spotify/callback" do
    before do
      allow(SecureRandom).to receive(:hex).and_return("fixedstate")
      get spotify_login_path
      expect(session[:spotify_state]).to eq("fixedstate")
    end

    it "rejects state mismatch" do
      get spotify_callback_path, params: { state: "wrong", code: "x" }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/State mismatch/i)
    end

    it "handles error param" do
      get spotify_callback_path, params: { state: "fixedstate", error: "access_denied" }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/Spotify error/i)
    end

    it "creates/updates user and signs in on success" do
      user = perform_spotify_sign_in
      expect(user.display_name).to eq("DJ Test")
      expect(user.email).to eq("dj@example.com")
      expect(user.avatar_url).to eq("http://img")
      expect(user.access_token).to be_present
      expect(session[:user_id]).to eq(user.id)
    end

    it "handles user save validation errors gracefully" do
      oauth = instance_double("Spotify::Oauth")
      allow(Spotify::Oauth).to receive(:new).and_return(oauth)
      allow(oauth).to receive(:exchange_code).and_return(
        { "access_token" => "AT", "refresh_token" => "RT", "expires_in" => 3600 }
      )
      allow_any_instance_of(SpotifyAuthController).to receive(:fetch_profile!).and_return(
        { "id" => "uid", "display_name" => "X", "email" => "bad", "images" => [] }
      )
      allow_any_instance_of(User).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(User.new))

      get spotify_callback_path, params: { state: "fixedstate", code: "ok" }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/Sign-in failed/i)
    end
  end

  describe "GET /spotify/token" do
    let!(:user) do
      User.create!(
        spotify_uid: "spotify-uid",
        display_name: "Test",
        email: "t@example.com",
        access_token: "AT",
        refresh_token: "RT",
        token_expires_at: expires_at
      )
    end

    context "when not signed in" do
      let(:expires_at) { 1.hour.from_now }
      it "returns 401" do
        get spotify_token_path
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when signed in and token valid" do
      let(:expires_at) { 10.minutes.from_now }
      it "returns current token json" do
        perform_spotify_sign_in(profile_overrides: { "id" => user.spotify_uid })
        get spotify_token_path
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["access_token"]).to eq("AT")
        expect(body["expires_in"]).to be > 0
      end
    end

    context "when signed in and token expired" do
      let(:expires_at) { 1.minute.ago }
      it "refreshes and returns new token json" do
        perform_spotify_sign_in(
          profile_overrides: { "id" => user.spotify_uid },
          tokens_overrides:  { "expires_in" => -60 }
        )

        oauth = instance_double("Spotify::Oauth")
        allow(Spotify::Oauth).to receive(:new).and_return(oauth)
        allow(oauth).to receive(:refresh).with("RT").and_return(
          { "access_token" => "NEW", "refresh_token" => nil, "expires_in" => 3600 }
        )

        get spotify_token_path
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["access_token"]).to eq("NEW")
        expect(user.reload.access_token).to eq("NEW")
      end

      it "returns 401 if refresh fails" do
        perform_spotify_sign_in(
          profile_overrides: { "id" => user.spotify_uid },
          tokens_overrides:  { "expires_in" => -60 }
        )

        oauth = instance_double("Spotify::Oauth")
        allow(Spotify::Oauth).to receive(:new).and_return(oauth)
        allow(oauth).to receive(:refresh).with("RT").and_return(nil)

        get spotify_token_path
        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)["error"]).to eq("refresh_failed")
      end
    end
  end
end
