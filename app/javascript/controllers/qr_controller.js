import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["result", "cameraSelect"]

  connect() {
    console.log("[qr] connected", this.element)
    this.html5 = null
    this.isScanning = false
    this._wasFullscreen = false
    if (!window.Html5Qrcode) {
      console.warn("html5-qrcode not loaded. Include <script src='https://unpkg.com/html5-qrcode'></script>")
    }
    // startFullscreen()
  }

  disconnect() { this.stop() }

  async startFullscreen() {
    const el = this.element.querySelector("#qr-reader") || this.element
    try {
      if (el.requestFullscreen && !document.fullscreenElement) {
        await el.requestFullscreen()
        this._wasFullscreen = true
        el.style.width = "100vw"
        el.style.height = "100vh"
        el.style.maxHeight = "100vh"
      }
    } catch(_) {}
    await this.restart()
  }

  async start() {
    if (!window.Html5Qrcode || this.isScanning) return
    this.isScanning = true
    this.html5 = new window.Html5Qrcode("qr-reader")

    // Pick a camera (prefer back)
    const cams = await window.Html5Qrcode.getCameras()
    if (this.hasCameraSelectTarget) {
      this.cameraSelectTarget.innerHTML = ""
      cams.forEach(c => {
        const opt = document.createElement("option")
        opt.value = c.id
        opt.textContent = c.label || c.id
        this.cameraSelectTarget.appendChild(opt)
      })
    }
    const backCam = cams.find(c => /back|rear|environment/i.test(c.label))
    const camId = (this.hasCameraSelectTarget && this.cameraSelectTarget.value) || (backCam ? backCam.id : (cams[0] && cams[0].id))

    await this.html5.start(
      camId ? { deviceId: { exact: camId } } : { facingMode: "environment" },
      // If fullscreen, let the library size the box; else a compact qrbox:
      document.fullscreenElement ? { fps: 15 } : { fps: 10, qrbox: 260, aspectRatio: 1 },
      (txt) => this._onScan(txt),
      (_err) => {}
    )
    this._toggleUi(true)
  }

  async stop() {
    if (!this.html5) return
    try { await this.html5.stop() } catch(_) {}
    try { await this.html5.clear() } catch(_) {}
    this.html5 = null
    this.isScanning = false
    this._toggleUi(false)

    if (this._wasFullscreen && document.fullscreenElement) {
      try { await document.exitFullscreen() } catch(_) {}
      this._wasFullscreen = false
    }
  }

  async restart() { await this.stop(); await this.start() }

  async _onScan(decodedText) {
    if (!this.isScanning) return
    this.isScanning = false

    if (this.hasResultTarget) this.resultTarget.textContent = decodedText
    const payload = this._parse(decodedText)
    this.element.dispatchEvent(
      new CustomEvent("hitster:play", { detail: { payload }, bubbles: true })
    )
    await this.stop()
  }

  _parse(text) {
    try {
      const j = JSON.parse(text)
      if (j && Array.isArray(j.uris) && j.uris.length) return j.uris
    } catch (_) {}
    return text.trim()
  }

  _toggleUi(active) {
    if (!this.element) return
    const startBtn = this.element.querySelector("[data-action='qr#start']")
    const stopBtn  = this.element.querySelector("[data-action='qr#stop']")
    if (startBtn) startBtn.disabled = active
    if (stopBtn)  stopBtn.disabled  = !active
  }
}
