require "rqrcode"
require "rqrcode_svg"

module QrCode
  class Renderer
    # size in px of the final square; module_px = pixel size of each QR dot
    def self.inline_svg(data, max_mm: 30, quiet_modules: 4)
      qr = RQRCode::QRCode.new(data.to_s, level: :h)

      modules        = qr.modules.length
      module_px      = 8
      total_modules  = modules + quiet_modules * 2
      total_px       = total_modules * module_px
      offset_px      = quiet_modules * module_px

      # Render QR with white modules instead of black
      svg = qr.as_svg(
        offset: offset_px,
        color: "#ffffff",             # modules drawn in white
        shape_rendering: "crispEdges",
        module_size: module_px,
        standalone: true,
        use_path: true
      )

      # Black background instead of white
      svg.sub!(
        %r{<svg([^>]+)>},
        '<svg\1><rect width="100%" height="100%" fill="#000000"/>'
      )

      # Set physical size to 30mm
      svg.sub!(/width="[^"]*"/,  "")
      svg.sub!(/height="[^"]*"/, "")
      unless svg =~ /viewBox=/
        svg.sub!(%r{<svg([^>]*)>},
                 %Q(<svg\\1 viewBox="0 0 #{total_px} #{total_px}">))
      end
      svg.sub!(%r{<svg([^>]*)>},
               %Q(<svg\\1 width="#{max_mm}mm" height="#{max_mm}mm" preserveAspectRatio="xMidYMid meet">))

      svg
    end
  end
end
