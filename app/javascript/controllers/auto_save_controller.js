import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    draftId: String,
    page: String,
    restoreAutosaveUrl: String
  }

  static targets = ["scoreField"]

  connect() {
    this.STORAGE_KEY = "tt_log_autosave"

    if (this.pageValue === "index") {
      this.checkAndShowBanner()
    } else {
      this.startAutoSave()
      window.addEventListener("beforeunload", this._boundSaveState = this.saveState.bind(this))
    }
  }

  disconnect() {
    if (this.pageValue !== "index") {
      this.stopAutoSave()
      if (this._boundSaveState) {
        window.removeEventListener("beforeunload", this._boundSaveState)
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
    const data = this.collectFormData()
    localStorage.setItem(this.STORAGE_KEY, JSON.stringify(data))
  }

  clearStorage() {
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

    const gameScores = {}
    if (this.hasScoreFieldTarget) {
      this.scoreFieldTargets.forEach((input) => {
        const style = input.dataset.autoSaveStyleParam
        const kind = input.dataset.autoSaveKindParam
        if (style && kind) {
          gameScores[style] = gameScores[style] || {}
          gameScores[style][kind] = parseInt(input.value, 10) || 0
        }
      })
    }

    return {
      draft_id: draftIdInput ? draftIdInput.value : this.draftIdValue,
      match_date: matchDateInput ? matchDateInput.value : "",
      match_name: matchNameInput ? matchNameInput.value : "",
      player_name: playerNameInput ? playerNameInput.value : "",
      opponent_name: opponentNameInput ? opponentNameInput.value : "",
      memo: memoInput ? memoInput.value : "",
      match_format: matchFormatInput ? matchFormatInput.value : "5",
      game_scores: gameScores
    }
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
      window.location.href = `/match_infos/new?draft_id=${data.draft_id}`
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

    const gameScoresInput = document.createElement("input")
    gameScoresInput.type = "hidden"
    gameScoresInput.name = "game_scores"
    gameScoresInput.value = JSON.stringify(data.game_scores || {})
    form.appendChild(gameScoresInput)

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
}
