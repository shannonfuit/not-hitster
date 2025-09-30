require "rails_helper"

RSpec.describe "Sessions", type: :request do
  it "DELETE /logout clears session and redirects" do
    user = User.create!(spotify_uid: "u3", display_name: "X",
                        access_token: "AT", refresh_token: "RT", token_expires_at: 1.hour.from_now)

    get root_path
    allow_any_instance_of(ActionDispatch::Request).to receive(:session).and_return(session)
    session[:user_id] = user.id

    delete logout_path
    expect(response).to redirect_to(root_path)
    expect(session[:user_id]).to be_nil
    expect(flash[:notice]).to match(/Signed out/i)
  end
end
