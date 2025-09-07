require "rails_helper"

RSpec.describe "SpotifyAuth", type: :request do
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
      # seed a state by hitting the login endpoint
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

    it "creates or updates a user and signs in on success" do
      # Stub token exchange
      tokens_json = { access_token: "AT", refresh_token: "RT", expires_in: 3600 }.to_json
      allow(Net::HTTP).to receive(:start).and_wrap_original do |_, *args, **kwargs, &blk|
        blk.call(HttpStub::FakeHttp.new(tokens_json))
      end

      # Stub profile fetch by stubbing controller private method
      allow_any_instance_of(SpotifyAuthController).to receive(:fetch_profile).and_return(
        {
          "id" => "spotify-uid",
          "display_name" => "DJ Test",
          "email" => "dj@example.com",
          "images" => [{ "url" => "http://img" }]
        }
      )

      get spotify_callback_path, params: { state: "fixedstate", code: "ok" }
      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to match(/Signed in with Spotify/i)

      user = User.find_by(spotify_uid: "spotify-uid")
      expect(user).to be_present
      expect(user.access_token).to eq("AT")
      expect(user.refresh_token).to eq("RT")
      expect(session[:user_id]).to eq(user.id)
    end
  end

  describe "GET /spotify/token" do
    let!(:user) do
      User.create!(
        spotify_uid: "u1",
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
        # sign in
        get root_path # warm up a request to get a session
        allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session)
        session[:user_id] = user.id

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
        # sign in
        get root_path
        allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session)
        session[:user_id] = user.id

        refreshed = { access_token: "NEW", refresh_token: nil, expires_in: 3600 }.to_json
        allow(Net::HTTP).to receive(:start).and_wrap_original do |_, *args, **kwargs, &blk|
          blk.call(HttpStub::FakeHttp.new(refreshed))
        end

        get spotify_token_path
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["access_token"]).to eq("NEW")
        expect(user.reload.access_token).to eq("NEW")
      end
    end
  end
end
