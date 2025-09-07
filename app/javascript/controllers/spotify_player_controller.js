import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { tokenUrl: String }
  static targets = ["status", "playButton", "pauseButton"]

  connect() {
    console.log("[spotify-player] connected", this.element)
    this.player = null
    this.deviceId = null
    this.poll = null
    this._hiddenMeta = null
    this._isPlaying = false
    this._setStatus("Not connected")
    this.connectPlayer()
  }

  disconnect() {
    if (this.player) this.player.disconnect()
    if (this.poll) clearInterval(this.poll)
  }

  async connectPlayer() { await this._ensurePlayer() }

  async play(payload) {
    await this._ensurePlayer()
    for (let i = 0; i < 30 && !this.deviceId; i++) { await new Promise(r => setTimeout(r, 100)) }

    await this._transferPlaybackHere()
    const token = await this._fetchAccessToken()

    // TODO: remove hardcoded debug track
    payload = 'spotify:track:3n3Ppam7vgaVa1iaRUc9Lp'
    const body =
      Array.isArray(payload) ? { uris: payload } :
      (typeof payload === "string") ? { uris: [payload] } :
      { uris: [] }

    await fetch(`https://api.spotify.com/v1/me/player/play?device_id=${encodeURIComponent(this.deviceId)}`, {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(body)
    })

    this._isPlaying = true
    this._updateButtons()
  }

  async pause()  {
    if (this.player) { await this.player.pause() }
    this._isPlaying = false
    this._updateButtons()
  }

  async resume() {
    if (this.player) { await this.player.resume() }
    this._isPlaying = true
    this._updateButtons()
  }

  async nextAndScan() {
    try { await this.pause() } catch(_) {}
    this.element.dispatchEvent(new CustomEvent("hitster:scan-next", { bubbles: true }))
  }

  // -------- internals --------
  async _ensurePlayer() {
    if (this.player) return;

    if (window.__spotifySDKReady) { await window.__spotifySDKReady }
    if (!window.Spotify || !window.Spotify.Player) throw new Error("Spotify Web Playback SDK not loaded")

    await this._fetchAccessToken()

    this.player = new window.Spotify.Player({
      name: "Not-hitster Web Player",
      getOAuthToken: async cb => cb(await this._fetchAccessToken()),
      volume: 0.85
    })

    this.player.addListener("ready", ({ device_id }) => {
      this.deviceId = device_id
      this._setStatus("Player ready ✓")
      this._updateButtons()
    })
    this.player.addListener("authentication_error", ({ message }) => this._setStatus(`Auth error: ${message}`))
    this.player.addListener("account_error",        ({ message }) => this._setStatus(`Account error: ${message}`))
    this.player.addListener("initialization_error", ({ message }) => this._setStatus(`Init error: ${message}`))

    await this.player.connect()

    // Poll now playing to keep UI in sync
    this.poll = setInterval(() => this._refreshNowPlaying(), 1500)
  }

  async _fetchAccessToken() {
    const res = await fetch(this.tokenUrlValue, { credentials: "same-origin" })
    if (!res.ok) throw new Error("Token fetch failed (are you signed in + Premium?)")
    return (await res.json()).access_token
  }

  async _transferPlaybackHere() {
    const token = await this._fetchAccessToken()
    await fetch("https://api.spotify.com/v1/me/player", {
      method: "PUT",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify({ device_ids: [this.deviceId], play: true })
    })
  }

  async _refreshNowPlaying() {
    try {
      const token = await this._fetchAccessToken()
      const res = await fetch("https://api.spotify.com/v1/me/player/currently-playing?additional_types=track", {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (res.status === 204) return
      const data = await res.json()
      const item = data?.item
      if (!item) return

      this._hiddenMeta = {
        title: item.name,
        artist: (item.artists || []).map(a => a.name).join(", "),
        year: (item.album?.release_date || "").slice(0, 4)
      }

      if (typeof data.is_playing === "boolean") {
        this._isPlaying = data.is_playing
        this._updateButtons()
      }
    } catch (_) {}
  }

  async playFromEvent(event) {
    const { payload } = event.detail || {}
    if (!payload) return
    try { await this.play(payload) } catch (e) { console.error("Play failed:", e) }
  }

  _setStatus(t) { if (this.hasStatusTarget) this.statusTarget.textContent = `Status: ${t}` }
  
  _updateButtons() {
    const show = (el) => { if (el) el.classList.remove("d-none") }
    const hide = (el) => { if (el) el.classList.add("d-none") }

    if (this._isPlaying) {
      hide(this.playButtonTarget)
      show(this.pauseButtonTarget)
    } else {
      show(this.playButtonTarget)
      hide(this.pauseButtonTarget)
    }
  }
}