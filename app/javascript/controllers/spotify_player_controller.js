import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { tokenUrl: String }
  static targets = ["status", "playButton", "pauseButton"]

  connect() {
    console.debug("Spotify Player controller connected")
    this.player = null
    this.deviceId = null
    this.poll = null
    this._isPlaying = false
    this._setStatus("Not connected")
  }

  disconnect() {
    if (this.player) this.player.disconnect()
    if (this.poll) clearInterval(this.poll)
  }

  async connectPlayer() { await this._ensurePlayer() }

  async play(payload) {
    console.debug("Spotify Player: play", payload);
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
    console.debug("Spotify Player: pause");
    if (this.player) await this.player.pause();  
    this._isPlaying = false; 
    this._updateButtons() 
  }
  async resume() { 
    console.debug("Spotify Player: resume");
    if (this.player) await this.player.resume(); 
    this._isPlaying = true;  
    this._updateButtons() 
  }

  async stop() {
    try { await this.pause() } catch(_) {}
    // Go back to Play Game screen
    this._dispatch("ui:show-playgame")
  }

  async nextAndScan() {
    try { await this.pause() } catch(_) {}
    this._dispatch("player:scan-next") // Root has data-action to route this to qr#start
  }

  // ---- internals
  async _ensurePlayer() {
    if (this.player) return
    if (window.__spotifySDKReady) await window.__spotifySDKReady
    if (!window.Spotify || !window.Spotify.Player) throw new Error("Spotify Web Playback SDK not loaded")

    await this._fetchAccessToken()
    this.player = new window.Spotify.Player({
      name: "Hitster Web Player",
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
      body: JSON.stringify({ device_ids: [this.deviceId], play: false })
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
      if (typeof data.is_playing === "boolean") {
        this._isPlaying = data.is_playing
        this._updateButtons()
      }
    } catch(_) {}
  }

  // playFromEvent(event) {
  //   const { payload } = event.detail || {}
  //   if (payload) this.play(payload).catch(e => console.error("Play failed:", e))
  // }

  handleQrScan(event) {
    const qrToken = event.detail.qrToken
    if (qrToken) {
      this._scanAndFetchSpotifyUUID(qrToken)
    } else {
      console.warn("No qr_token in event detail:", event)
    }
  }

  async _scanAndFetchSpotifyUUID(qrToken) {
    try {
      const res = await fetch(`/songs/lookup/${encodeURIComponent(qrToken)}`, {
        headers: { "Accept": "application/json" },
        credentials: "same-origin"
      })
  
      if (!res.ok) throw new Error("Song lookup failed")
  
      const data = await res.json()
      if (!data.spotify_uuid) throw new Error("No Spotify UUID returned")
  
      console.debug("Fetched Spotify UUID:", data.spotify_uuid)
      this.play(data.spotify_uuid)
    } catch (error) {
      console.error("Error fetching Spotify UUID:", error)
      this._setStatus("Song not found or error")
    }
  }

  _setStatus(t) { if (this.hasStatusTarget) this.statusTarget.textContent = `Status: ${t}` }

  _updateButtons() {
    const show = (el) => { if (el) el.classList.remove("d-none") }
    const hide = (el) => { if (el) el.classList.add("d-none") }
    if (this._isPlaying) { 
      hide(this.playButtonTarget); 
      show(this.pauseButtonTarget) 
    }
    else { 
      show(this.playButtonTarget); 
      hide(this.pauseButtonTarget) 
    }
  }

  _dispatch(name, detail = {}) {
    this.element.dispatchEvent(new CustomEvent(name, { bubbles: true, detail }))
  }
}