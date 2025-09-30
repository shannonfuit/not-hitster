Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self, "https://sdk.scdn.co", "https://unpkg.com", "https://cdn.jsdelivr.net"
    policy.connect_src :self, "https://api.spotify.com", "https://accounts.spotify.com"
    policy.img_src     :self, :data, :blob, "https://i.scdn.co"
    policy.media_src   :self, :blob
    policy.worker_src  :self, :blob
    policy.style_src   :self, "https://fonts.googleapis.com"
    policy.font_src    :self, :data, "https://fonts.gstatic.com"
    policy.frame_src   :self, "https://sdk.scdn.co"
    # (Optional) some Spotify embeds use open.spotify.com in iframes:
    # policy.frame_src :self, "https://sdk.scdn.co", "https://open.spotify.com"

    # Keep this if you’re using nonces (recommended)
    config.content_security_policy_nonce_generator  = ->(_request) { SecureRandom.base64(16) }
    config.content_security_policy_nonce_directives = %w[script-src style-src]
  end
end
