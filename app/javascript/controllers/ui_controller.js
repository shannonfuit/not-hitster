import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["signIn", "playGame", "scanner", "controls"]

  connect() {
    console.debug("UI controller connected")
    if (this.hasPlayGameTarget) this._only(this.playGameTarget)
  }

  // Called by the Play game button
  startGame() {
    console.debug("UI: Starting game, showing scanner")
    this.showScanner()
  }

  showScanner()  { if (this.hasScannerTarget)  this._only(this.scannerTarget) }
  showControls() { if (this.hasControlsTarget) this._only(this.controlsTarget) }
  showPlayGame() { if (this.hasPlayGameTarget) this._only(this.playGameTarget) }

  _only(targetEl) {
    const groups = [
      this.hasPlayGameTarget && this.playGameTarget,
      this.hasScannerTarget && this.scannerTarget,
      this.hasControlsTarget && this.controlsTarget,
    ].filter(Boolean)

    groups.forEach(el => el.classList.add("d-none"))
    targetEl.classList.remove("d-none")
  }
}
