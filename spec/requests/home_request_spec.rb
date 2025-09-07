require "rails_helper"

RSpec.describe "Home", type: :request do
  it "shows sign-in button when logged out" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Sign in with Spotify")
  end

  it "shows user info when logged in" do
    user = User.create!(spotify_uid: "u4", display_name: "Pat",
                        access_token: "AT", refresh_token: "RT", token_expires_at: 1.hour.from_now)

    get root_path
    allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session)
    session[:user_id] = user.id

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Pat")
  end
end
