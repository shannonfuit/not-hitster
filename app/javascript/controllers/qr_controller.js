import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.debug("QR controller connected")
    this.html5 = null
    this.isScanning = false
  }

  disconnect() { this.stop() }

  async start() {
    console.debug("QR: Starting in-container scan")
    this._dispatch("ui:show-scanner") // show the scanner panel
    await this._start()
  }

  async _start() {
    if (!window.Html5Qrcode || this.isScanning) return
    this.isScanning = true
    this.html5 = new window.Html5Qrcode("qr-reader")

    const cams = await window.Html5Qrcode.getCameras()
    const backCam = cams.find(c => /back|rear|environment/i.test(c.label))
    const camId = backCam ? backCam.id : (cams[0] && cams[0].id)

    await this.html5.start(
      camId ? { deviceId: { exact: camId } } : { facingMode: "environment" },
      { fps: 15 },
      (txt) => this._onScan(txt),
      (_err) => {}
    )
  }

  async stop() {
    if (this.html5) {
      try { await this.html5.stop() } catch(_) {}
      try { await this.html5.clear() } catch(_) {}
      this.html5 = null
    }
    this.isScanning = false
  }

  async _onScan(decodedText) {
    if (!this.isScanning) return
    this.isScanning = false

    const payload = this._parse(decodedText)
    this._dispatch("hitster:play", { payload })

    await this.stop()
    this._dispatch("ui:show-controls")
  }

  _parse(text) {
    try {
      const j = JSON.parse(text)
      if (j && Array.isArray(j.uris) && j.uris.length) return j.uris
    } catch (_) {}
    return text.trim()
  }

  _dispatch(name, detail = {}) {
    this.element.dispatchEvent(new CustomEvent(name, { bubbles: true, detail }))
  }
}