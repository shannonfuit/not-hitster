Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.2").to_f
  config.environment = ENV.fetch("SENTRY_ENV", Rails.env)
  config.send_default_pii = true
end
