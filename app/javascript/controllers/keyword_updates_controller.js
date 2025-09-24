import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["adsCount", "linksCount", "status", "adsContainer", "linksContainer"]
  static values = {
    url: String,
    status: String
  }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    if (this.statusValue === "pending" || this.statusValue === "processing") {
      this.poll()
      this.timer = setInterval(() => {
        this.poll()
      }, 2000) // Poll every 2 seconds
    }
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "application/json"
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateUI(data)

        // Stop polling if completed or failed
        if (data.status === "completed" || data.status === "failed") {
          this.stopPolling()
        }
      }
    } catch (error) {
      console.error("Failed to fetch keyword updates:", error)
    }
  }

  updateUI(data) {
    // Update counts
    if (this.hasAdsCountTarget) {
      this.adsCountTarget.textContent = data.ads_count
    }

    if (this.hasLinksCountTarget) {
      this.linksCountTarget.textContent = data.links_count
    }

    // Update status
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = data.status_text
      this.statusTarget.className = data.status_class
    }

    // Update ads list
    if (this.hasAdsContainerTarget && data.ads && data.ads.length > 0) {
      this.adsContainerTarget.innerHTML = this.renderAds(data.ads)
    }

    // Update links list
    if (this.hasLinksContainerTarget && data.links && data.links.length > 0) {
      this.linksContainerTarget.innerHTML = this.renderLinks(data.links)
    }

    // Update status value for next poll
    this.statusValue = data.status
  }

  renderAds(ads) {
    return ads.map((ad, index) => `
      <div class="rounded border border-orange-200 bg-orange-50/50 p-3">
        <div class="mb-1 flex items-start justify-between">
          <h3 class="text-xs font-medium text-slate-900 flex-1 truncate pr-2">
            ${this.escapeHtml(ad.title || 'Untitled')}
          </h3>
          <span class="ml-2 rounded bg-orange-200 px-2 py-1 text-xs font-medium text-orange-800 flex-shrink-0">
            AD
          </span>
        </div>
        ${ad.url ? `
          <p class="text-xs text-blue-600 truncate">
            <a href="${this.escapeHtml(ad.url)}" target="_blank" class="hover:underline break-all">
              ${this.escapeHtml(ad.url)}
            </a>
          </p>
        ` : ''}
      </div>
    `).join('')
  }

  renderLinks(links) {
    return links.map((link, index) => {
      const url = typeof link === 'string' ? link : (link.url || '')
      const title = typeof link === 'string' ? link : (link.title || 'Untitled')

      return `
        <div class="rounded border border-green-200 bg-green-50/50 p-3">
          <div class="mb-1 flex items-start justify-between">
            <h3 class="text-xs font-medium text-slate-900 flex-1 truncate pr-2">
              ${this.escapeHtml(title)}
            </h3>
            <span class="ml-2 text-xs font-medium text-green-600 flex-shrink-0">
              #${index + 1}
            </span>
          </div>
          ${url ? `
            <p class="text-xs text-blue-600 truncate">
              <a href="${this.escapeHtml(url)}" target="_blank" class="hover:underline break-all">
                ${this.escapeHtml(url)}
              </a>
            </p>
          ` : ''}
        </div>
      `
    }).join('')
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}