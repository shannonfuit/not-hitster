# app/controllers/spotify_auth_controller.rb
class SpotifyAuthController < ApplicationController
  require "json"
  protect_from_forgery except: :token

  def login
    state = SecureRandom.hex(16)
    session[:spotify_state] = state
    redirect_to Spotify::AuthorizeUrl.build(state:), allow_other_host: true
  end

  def callback
    if params[:state] != session.delete(:spotify_state)
      redirect_to root_path, alert: "State mismatch" and return
    end
    if params[:error].present?
      redirect_to root_path, alert: "Spotify error: #{params[:error]}" and return
    end

    tokens = Spotify::Oauth.new.exchange_code(params[:code])
    unless tokens&.dig("access_token")
      redirect_to root_path, alert: "Failed to obtain tokens." and return
    end

    # get profile
    profile = fetch_profile(tokens["access_token"])
    unless profile&.dig("id")
      redirect_to root_path, alert: "Failed to fetch profile." and return
    end

    user = User.find_or_initialize_by(spotify_uid: profile["id"])
    user.display_name     = profile["display_name"].presence || profile.dig("id")
    user.email            = profile.dig("email")
    user.avatar_url       = profile.dig("images", 0, "url")
    user.access_token     = tokens["access_token"]
    user.refresh_token    = tokens["refresh_token"] if tokens["refresh_token"].present?
    user.token_expires_at = Time.current + tokens["expires_in"].to_i.seconds
    user.save!

    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in with Spotify!"
  end

  # For the Web Playback SDK later
  # # TODO, DRY up, refactor to use TokenProvider service
  def token
    user = current_user
    return render(json: { error: "not_authenticated" }, status: :unauthorized) unless user

    if user.token_expired?
      tokens = Spotify::Oauth.new.refresh(user.refresh_token)
      return render(json: { error: "refresh_failed" }, status: :unauthorized) unless tokens&.dig("access_token")

      user.update!(
        access_token:     tokens["access_token"],
        token_expires_at: Time.current + tokens["expires_in"].to_i.seconds,
        refresh_token:    (tokens["refresh_token"].presence || user.refresh_token)
      )
    end

    expires_in = (user.token_expires_at - Time.current).to_i
    render json: { access_token: user.access_token, expires_in: expires_in.positive? ? expires_in : 0 }
  end

  private

  def fetch_profile(access_token)
    uri = URI("https://api.spotify.com/v1/me")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{access_token}"
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| JSON.parse(h.request(req).body) }
  rescue
    nil
  end
end
