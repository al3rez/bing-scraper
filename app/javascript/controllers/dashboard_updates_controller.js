import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["totalKeywords", "processedKeywords", "totalUploads", "processingRate", "tableBody"]
  static values = { url: String }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    // Only poll if there are pending/processing keywords
    const hasPendingKeywords = this.element.dataset.hasPendingKeywords === 'true'
    if (hasPendingKeywords) {
      this.poll()
      this.timer = setInterval(() => this.poll(), 3000) // Poll every 3 seconds
    }
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  async poll() {
    try {
      // Get current page parameter from URL if we're paginated
      const currentPage = this.getCurrentPage()
      const url = new URL(this.urlValue || '/dashboard.json', window.location.origin)
      if (currentPage > 1) {
        url.searchParams.set('page', currentPage)
      }

      const response = await fetch(url, {
        headers: { 'Accept': 'application/json' }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateUI(data)

        // Stop polling if no more pending keywords
        if (!data.has_pending_keywords) {
          this.stopPolling()
        }
      }
    } catch (error) {
      console.error('Dashboard update failed:', error)
    }
  }

  getCurrentPage() {
    // Extract page number from current URL
    const urlParams = new URLSearchParams(window.location.search)
    return parseInt(urlParams.get('page')) || 1
  }

  updateUI(data) {
    // Update KPIs with animation
    this.updateCounter(this.totalKeywordsTarget, data.total_keywords)
    this.updateCounter(this.processedKeywordsTarget, data.processed_keywords)
    this.updateCounter(this.totalUploadsTarget, data.total_uploads)
    this.updateCounter(this.processingRateTarget, data.processing_rate + '%')

    // Replace entire table body with new content
    if (data.keywords && this.hasTableBodyTarget) {
      this.tableBodyTarget.innerHTML = this.buildTableRows(data.keywords)
    }
  }

  updateCounter(element, newValue) {
    if (element && element.textContent !== String(newValue)) {
      element.textContent = newValue
      // Add brief highlight animation
      element.classList.add('text-blue-600', 'transition-colors')
      setTimeout(() => {
        element.classList.remove('text-blue-600')
      }, 500)
    }
  }

  buildTableRows(keywords) {
    return keywords.map(keyword => {
      return `
        <tr class="hover:bg-slate-50">
          <td class="px-3 py-2 text-sm font-medium text-slate-900">
            <a href="/keywords/${keyword.id}" class="text-blue-600 hover:text-blue-800 underline">${keyword.phrase}</a>
          </td>
          <td class="px-3 py-2 text-sm text-slate-600">${keyword.ads_count}</td>
          <td class="px-3 py-2 text-sm text-slate-600">${keyword.links_count}</td>
          <td class="px-3 py-2 text-sm">
            ${this.getStatusHtml(keyword.status, keyword.scraped_at)}
          </td>
          <td class="px-3 py-2 text-sm text-slate-500 truncate max-w-32">${keyword.keyword_upload_original_filename}</td>
        </tr>
      `
    }).join('')
  }

  getStatusHtml(status, scrapedAt) {
    switch(status) {
      case 'pending':
        return `<span class="inline-flex items-center gap-1 text-slate-500">
          <span class="h-1.5 w-1.5 rounded-full bg-slate-400"></span>
          Queued
        </span>`
      case 'processing':
        return `<span class="inline-flex items-center gap-1 text-yellow-600">
          <span class="h-1.5 w-1.5 rounded-full bg-yellow-500 animate-pulse"></span>
          Scraping...
        </span>`
      case 'completed':
        if (scrapedAt) {
          const timeAgo = this.timeAgo(new Date(scrapedAt))
          return `<span class="inline-flex items-center gap-1 text-green-600">
            <span class="h-1.5 w-1.5 rounded-full bg-green-500"></span>
            ${timeAgo} ago
          </span>`
        } else {
          return `<span class="text-slate-400">-</span>`
        }
      case 'failed':
        return `<span class="inline-flex items-center gap-1 text-red-600">
          <span class="h-1.5 w-1.5 rounded-full bg-red-500"></span>
          Failed
        </span>`
      default:
        return `<span class="text-slate-400">-</span>`
    }
  }

  timeAgo(date) {
    const now = new Date()
    const diffInSeconds = Math.floor((now - date) / 1000)

    if (diffInSeconds < 60) {
      return 'less than a minute'
    } else if (diffInSeconds < 3600) {
      const minutes = Math.floor(diffInSeconds / 60)
      return `${minutes} minute${minutes > 1 ? 's' : ''}`
    } else if (diffInSeconds < 86400) {
      const hours = Math.floor(diffInSeconds / 3600)
      return `${hours} hour${hours > 1 ? 's' : ''}`
    } else {
      const days = Math.floor(diffInSeconds / 86400)
      return `${days} day${days > 1 ? 's' : ''}`
    }
  }
}