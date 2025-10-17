require "json"

class SpotifyAuthController < ApplicationController
  class SpotifyProfileError < StandardError; end

  protect_from_forgery except: :token
  skip_before_action :require_sign_in, only: %i[login callback token]

  def login
    state = SecureRandom.hex(16)
    session[:spotify_state] = state
    redirect_to Spotify::AuthorizeUrl.build(state:), allow_other_host: true
  end

  def callback
    expected_state = session[:spotify_state].to_s
    given_state    = params[:state].to_s

    unless ActiveSupport::SecurityUtils.secure_compare(expected_state, given_state)
      Rails.logger.error("State mismatch in Spotify callback: expected #{expected_state.inspect}, got #{given_state.inspect}")
      Sentry.capture_message(
        "Spotify OAuth state mismatch",
        level: :warning,
        extra: { expected_state:, got: given_state, request_id: request.request_id }
      )
      reset_session
      redirect_to root_path, alert: "State mismatch" and return
    end
    session.delete(:spotify_state)

    if params[:error].present?
      Rails.logger.error("Spotify callback error: #{params[:error]}")
      Sentry.capture_message(
        "Spotify callback error",
        level: :error,
        extra: { error: params[:error], query: request.query_parameters, request_id: request.request_id }
      )
      redirect_to root_path, alert: "Spotify error: #{params[:error]}" and return
    end

    tokens = Spotify::Oauth.new.exchange_code(params[:code])
    unless tokens&.dig("access_token")
      safe_tokens = { present: tokens.present?, keys: tokens&.keys }
      Rails.logger.error("Failed to exchange code for tokens: #{safe_tokens.inspect}")
      Sentry.capture_message("Spotify token exchange failed", level: :error, extra: safe_tokens.merge(request_id: request.request_id))
      redirect_to root_path, alert: "Failed to obtain tokens." and return
    end

    begin
      profile = fetch_profile!(tokens["access_token"])
    rescue => e
      Rails.logger.error("Failed to fetch Spotify profile: #{e.class}: #{e.message}")
      Sentry.capture_exception(e, extra: {
        access_token_sha1: Digest::SHA1.hexdigest(tokens["access_token"].to_s),
        endpoint: "/v1/me",
        request_id: request.request_id
      })
      redirect_to root_path, alert: "Failed to fetch profile." and return
    end

    unless profile&.dig("id")
      Rails.logger.error("Spotify profile missing id: #{profile.inspect}")
      Sentry.capture_message("Spotify profile missing id", level: :error, extra: { profile:, request_id: request.request_id })
      redirect_to root_path, alert: "Failed to fetch profile." and return
    end

    user = User.find_or_initialize_by(spotify_uid: profile["id"])
    user.display_name     = profile["display_name"].presence || profile["id"]
    user.email            = profile["email"]
    user.avatar_url       = profile.dig("images", 0, "url")
    user.access_token     = tokens["access_token"]
    user.refresh_token    = tokens["refresh_token"] if tokens["refresh_token"].present?
    user.token_expires_at = Time.current + tokens["expires_in"].to_i.seconds

    begin
      user.save!
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("User save failed: #{e.record.errors.full_messages.join(', ')}")
      Sentry.capture_exception(e, extra: { spotify_uid: profile["id"], request_id: request.request_id })
      redirect_to root_path, alert: "Sign-in failed. Please try again." and return
    end

    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice: "Signed in with Spotify!"
  end

  # For the Web Playback SDK later
  # TODO: DRY up, refactor to use TokenProvider service
  def token
    user = current_user
    return render(json: { error: "not_authenticated" }, status: :unauthorized) unless user

    if user.token_expired?
      tokens = Spotify::Oauth.new.refresh(user.refresh_token)
      unless tokens&.dig("access_token")
        Rails.logger.error("Spotify refresh failed for user_id=#{user.id}")
        Sentry.capture_message("Spotify token refresh failed", level: :error, extra: { user_id: user.id })
        return render(json: { error: "refresh_failed" }, status: :unauthorized)
      end

      user.update!(
        access_token:     tokens["access_token"],
        token_expires_at: Time.current + tokens["expires_in"].to_i.seconds,
        refresh_token:    (tokens["refresh_token"].presence || user.refresh_token)
      )
    end

    expires_in = (user.token_expires_at - Time.current).to_i
    render json: { access_token: user.access_token, expires_in: expires_in.positive? ? expires_in : 0 }
  end

  # TODO: Add test and button in UI
  def disconnect
    if current_user
      current_user.update(access_token: nil, refresh_token: nil, token_expires_at: nil)
      redirect_to root_path, notice: "Disconnected from Spotify."
    else
      redirect_to root_path, alert: "Not signed in."
    end
  end

  private

  def fetch_profile!(access_token)
    raise SpotifyProfileError, "Missing access token" if access_token.blank?

    uri = URI("https://api.spotify.com/v1/me")
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{access_token}"
    req["Accept"]        = "application/json"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 5
    http.read_timeout = 8

    res = http.start { |h| h.request(req) }

    unless res.is_a?(Net::HTTPSuccess)
      body_snippet = res.body.to_s[0, 500]
      Rails.logger.error("Spotify /me non-200: code=#{res.code} body=#{body_snippet}")
      Sentry.capture_message("Spotify /v1/me non-200", level: :error, extra: {
        endpoint: "/v1/me",
        status: res.code,
        body_snippet: body_snippet,
        headers: res.to_hash
      })
      raise SpotifyProfileError, "Spotify /me returned #{res.code}"
    end

    JSON.parse(res.body)
  rescue JSON::ParserError => e
    Rails.logger.error("Spotify /me JSON parse error: #{e.message} body=#{res&.body.to_s[0, 500]}")
    Sentry.capture_exception(e, extra: { endpoint: "/v1/me", body_snippet: res&.body.to_s[0, 500] })
    raise
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error("Spotify /me timeout: #{e.class}: #{e.message}")
    Sentry.capture_exception(e, extra: { endpoint: "/v1/me" })
    raise
  rescue OpenSSL::SSL::SSLError, SocketError, Errno::ECONNRESET, Errno::ETIMEDOUT => e
    Rails.logger.error("Spotify /me network/SSL error: #{e.class}: #{e.message}")
    Sentry.capture_exception(e, extra: { endpoint: "/v1/me" })
    raise
  end
end
