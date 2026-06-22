import { Controller } from "@hotwired/stimulus"

// Polls a status endpoint while an analysis runs in the background, and reloads
// the page once the job reaches a terminal state (ready / not_found / error) so
// the server can render the result (or redirect).
export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 2000 } }

  connect() {
    this.timer = setInterval(() => this.check(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async check() {
    try {
      const res = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!res.ok) return
      const { state } = await res.json()
      if (state && state !== "pending" && state !== "idle") {
        clearInterval(this.timer)
        window.location.reload()
      }
    } catch (_) {
      // transient network hiccup — keep polling
    }
  }
}
