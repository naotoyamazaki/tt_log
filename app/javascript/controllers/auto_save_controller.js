import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    draftId: String,
    page: String,
    restoreAutosaveUrl: String
  }

  static targets = ["scoreField", "rallyField"]

  connect() {
    this.STORAGE_KEY = "tt_log_autosave"
    this.finalizing = false

    if (this.pageValue === "index") {
      this.checkAndShowBanner()
    } else {
      this.startAutoSave()
      window.addEventListener("beforeunload", this._boundSaveState = this.saveState.bind(this))
      document.addEventListener("turbo:before-visit", this._boundSaveState)
    }
  }

  disconnect() {
    if (this.pageValue !== "index") {
      this.stopAutoSave()
      if (this._boundSaveState) {
        window.removeEventListener("beforeunload", this._boundSaveState)
        document.removeEventListener("turbo:before-visit", this._boundSaveState)
      }
    }
  }

  startAutoSave() {
    this.autoSaveTimer = setInterval(() => this.saveState(), 30000)
  }

  stopAutoSave() {
    if (this.autoSaveTimer) clearInterval(this.autoSaveTimer)
  }

  saveState() {
    if (this.finalizing) return

    const data = this.collectFormData()
    localStorage.setItem(this.STORAGE_KEY, JSON.stringify(data))
  }

  clearStorage() {
    this.finalizing = true
    this.stopAutoSave()
    localStorage.removeItem(this.STORAGE_KEY)
  }

  collectFormData() {
    const form = this.element
    const draftIdInput = form.querySelector('input[name="draft_id"]')
    const matchDateInput = form.querySelector('input[name="match_info[match_date]"]')
    const matchNameInput = form.querySelector('input[name="match_info[match_name]"]')
    const playerNameInput = form.querySelector('input[name="match_info[player_name]"]')
    const opponentNameInput = form.querySelector('input[name="match_info[opponent_name]"]')
    const memoInput = form.querySelector('textarea[name="match_info[memo]"]')
    const matchFormatInput = form.querySelector('select[name="match_info[match_format]"]')
    const patternsInput = form.querySelector('input[name="patterns"]')
    const firstServerInput = form.querySelector('input[name="first_server"]')
    const analysisTypeInput = form.querySelector('input[name="match_info[analysis_type]"]')
    const rallies = this._collectRallies()

    return {
      draft_id: draftIdInput ? draftIdInput.value : this.draftIdValue,
      match_date: matchDateInput ? matchDateInput.value : "",
      match_name: matchNameInput ? matchNameInput.value : "",
      player_name: playerNameInput ? playerNameInput.value : "",
      opponent_name: opponentNameInput ? opponentNameInput.value : "",
      memo: memoInput ? memoInput.value : "",
      match_format: matchFormatInput ? matchFormatInput.value : "5",
      patterns: patternsInput ? patternsInput.value : null,
      first_server: firstServerInput ? firstServerInput.value : null,
      analysis_type: analysisTypeInput ? analysisTypeInput.value : null,
      rallies: rallies
    }
  }

  _collectRallies() {
    const serializedInput = this.element.querySelector('input[name="rallies"]')
    if (serializedInput && serializedInput.value) {
      try {
        return JSON.parse(serializedInput.value)
      } catch (_e) {
        // ignore
      }
    }
    return []
  }

  checkAndShowBanner() {
    const raw = localStorage.getItem(this.STORAGE_KEY)
    if (!raw) return

    try {
      JSON.parse(raw)
      const banner = document.getElementById("autosave-banner")
      if (banner) banner.classList.remove("d-none")
    } catch (_e) {
      localStorage.removeItem(this.STORAGE_KEY)
    }
  }

  restoreAutosave(event) {
    event.preventDefault()
    const raw = localStorage.getItem(this.STORAGE_KEY)
    if (!raw) return

    let data
    try {
      data = JSON.parse(raw)
    } catch (_e) {
      localStorage.removeItem(this.STORAGE_KEY)
      return
    }

    if (data.draft_id) {
      localStorage.removeItem(this.STORAGE_KEY)
      const path = data.analysis_type === 'serve_receive'
        ? `/match_infos/new_serve_receive?draft_id=${data.draft_id}`
        : `/match_infos/new?draft_id=${data.draft_id}`
      window.location.href = path
      return
    }

    const form = document.createElement("form")
    form.method = "post"
    form.action = this.restoreAutosaveUrlValue

    const csrfToken = document.querySelector('meta[name="csrf-token"]')
    if (csrfToken) {
      const csrfInput = document.createElement("input")
      csrfInput.type = "hidden"
      csrfInput.name = "authenticity_token"
      csrfInput.value = csrfToken.getAttribute("content")
      form.appendChild(csrfInput)
    }

    const fields = ["match_date", "match_name", "player_name", "opponent_name", "memo", "match_format"]
    fields.forEach((field) => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = field
      input.value = data[field] || ""
      form.appendChild(input)
    })

    if (data.patterns) {
      this._appendHiddenInput(form, "patterns", data.patterns)
      this._appendHiddenInput(form, "first_server", data.first_server || "")
      this._appendHiddenInput(form, "analysis_type", "serve_receive")
    } else {
      const ralliesInput = document.createElement("input")
      ralliesInput.type = "hidden"
      ralliesInput.name = "rallies_autosave"
      ralliesInput.value = JSON.stringify(data.rallies || [])
      form.appendChild(ralliesInput)
    }

    localStorage.removeItem(this.STORAGE_KEY)
    document.body.appendChild(form)
    form.submit()
  }

  dismissBanner(event) {
    event.preventDefault()
    localStorage.removeItem(this.STORAGE_KEY)
    const banner = document.getElementById("autosave-banner")
    if (banner) banner.classList.add("d-none")
  }

  _appendHiddenInput(form, name, value) {
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  }
}
