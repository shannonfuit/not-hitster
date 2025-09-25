require "grover"

module Pdf
  class Exporter
    DEFAULT_OPTS = {
      wait_until: "domcontentloaded",
      emulate_media: "print",
      timeout: 60_000,
      format: "A4",
      margin: { top: "0.75cm", right: "0.75cm", bottom: "0.75cm", left: "0.75cm" },
      launch_args: [ "--no-sandbox", "--disable-dev-shm-usage" ],
      raise_on_request_failure: true,
      raise_on_js_error: true
    }.freeze

    def initialize(html, **opts)
      @html = html
      @opts = DEFAULT_OPTS.merge(opts)
    end

    def to_pdf
      Grover.new(@html, **@opts).to_pdf
    end
  end
end
