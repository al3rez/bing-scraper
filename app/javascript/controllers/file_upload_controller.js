import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropZone", "uploadText", "fileName", "uploadBtn"]
  static values = { validateUrl: String }

  connect() {
    this.setupEventListeners()
  }

  setupEventListeners() {
    // Click to upload
    this.dropZoneTarget.addEventListener('click', () => this.inputTarget.click())

    // File selection handler
    this.inputTarget.addEventListener('change', (e) => this.handleFileSelection(e.target.files[0]))

    // Drag and drop handlers
    this.dropZoneTarget.addEventListener('dragover', (e) => this.handleDragOver(e))
    this.dropZoneTarget.addEventListener('dragleave', (e) => this.handleDragLeave(e))
    this.dropZoneTarget.addEventListener('drop', (e) => this.handleDrop(e))
  }

  handleDragOver(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.add('border-blue-500', 'bg-blue-100')
  }

  handleDragLeave(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.remove('border-blue-500', 'bg-blue-100')
  }

  handleDrop(e) {
    e.preventDefault()
    this.dropZoneTarget.classList.remove('border-blue-500', 'bg-blue-100')
    const files = e.dataTransfer.files
    if (files.length > 0) {
      this.inputTarget.files = files
      this.handleFileSelection(files[0])
    }
  }

  async handleFileSelection(file) {
    if (!file) {
      this.resetForm()
      return
    }

    // Basic client-side validation
    if (!this.validateFileSize(file) || !this.validateFileType(file)) {
      return
    }

    // Show loading state
    this.showLoadingState(file.name)

    try {
      // Send to backend for validation
      const formData = new FormData()
      formData.append('file', file)

      const response = await fetch(this.validateUrlValue, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const result = await response.json()

      if (result.valid) {
        this.showValidFile(file.name, result.keyword_count)
      } else {
        this.showInvalidFile(result.error)
      }
    } catch (error) {
      this.showInvalidFile('Failed to validate file')
    }
  }

  validateFileSize(file) {
    const maxSize = 5 * 1024 * 1024 // 5MB
    if (file.size > maxSize) {
      this.uploadTextTarget.textContent = 'File too large'
      this.fileNameTarget.textContent = ' - Max 5MB allowed'
      this.disableUpload()
      return false
    }
    return true
  }

  validateFileType(file) {
    const allowedTypes = ['text/csv', 'text/plain', 'application/csv']
    const isValidType = allowedTypes.includes(file.type) || file.name.endsWith('.csv')
    if (!isValidType) {
      this.uploadTextTarget.textContent = 'Invalid file type'
      this.fileNameTarget.textContent = ' - CSV files only'
      this.disableUpload()
      return false
    }
    return true
  }

  showLoadingState(fileName) {
    this.uploadTextTarget.textContent = fileName
    this.fileNameTarget.textContent = ' - Validating...'
    this.uploadBtnTarget.textContent = 'Validating...'
    this.uploadBtnTarget.disabled = true
  }

  showValidFile(fileName, keywordCount) {
    this.uploadTextTarget.textContent = fileName
    this.fileNameTarget.textContent = ` - ${keywordCount} keywords detected`
    this.uploadBtnTarget.textContent = 'Scrape!'
    this.uploadBtnTarget.disabled = false
    this.uploadBtnTarget.classList.remove('opacity-50')
  }

  showInvalidFile(error) {
    this.uploadTextTarget.textContent = error
    this.fileNameTarget.textContent = ' - Please fix and try again'
    this.disableUpload()
  }

  disableUpload() {
    this.uploadBtnTarget.disabled = true
    this.uploadBtnTarget.classList.add('opacity-50')
    this.uploadBtnTarget.textContent = 'Scrape'
  }

  resetForm() {
    this.uploadTextTarget.textContent = 'Click to upload'
    this.fileNameTarget.textContent = ' or drag and drop'
    this.disableUpload()
  }
}