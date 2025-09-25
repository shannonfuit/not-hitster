require "rqrcode"
require "rqrcode_svg"

module QrCode
  class Renderer
    # size in px of the final square; module_px = pixel size of each QR dot
    def self.inline_svg(data, module_px: 3, color: "000")
      qr = RQRCode::QRCode.new(data.to_s)
      qr.as_svg(
        offset: 0,
        color: color,
        shape_rendering: "crispEdges",
        module_size: module_px,
        standalone: true,
        use_path: true
      )
    end
  end
end
