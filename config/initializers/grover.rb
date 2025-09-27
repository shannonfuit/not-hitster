Grover.configure do |config|
  config.options = {
    launch_args: [ "--no-sandbox", "--disable-setuid-sandbox" ],
    executable_path: ENV.fetch("GOOGLE_CHROME_BIN", nil)
  }
end
