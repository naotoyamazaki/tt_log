import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "playerName", "opponentName",
    "playerPoints", "opponentPoints",
    "playerWins", "opponentWins",
    "gameHistory", "gameTab",
    "playerNameInput", "opponentNameInput",
    "gameSlot"
  ]

  connect() {
    this.gameScores = {}
    this.gameTabTargets.forEach(tab => {
      const idx = tab.dataset.gameIdx
      this.gameScores[idx] = {
        player: parseInt(tab.dataset.playerScore) || 0,
        opponent: parseInt(tab.dataset.opponentScore) || 0
      }
    })

    const numberInputs = this.element.querySelectorAll('input[type="number"]')
    numberInputs.forEach(input => {
      input.addEventListener('input', () => this.update())
    })

    this.element.querySelectorAll('[data-bs-toggle="tab"]').forEach(tab => {
      tab.addEventListener('shown.bs.tab', (event) => this.onGameTabShown(event))
    })

    this.update()
  }

  onGameTabShown(event) {
    this.updateFromActivePanel()
  }

  updateNames() {
    if (this.hasPlayerNameInputTarget && this.hasPlayerNameTarget) {
      this.playerNameTarget.textContent = this.playerNameInputTarget.value || "選手名"
    }
    if (this.hasOpponentNameInputTarget && this.hasOpponentNameTarget) {
      this.opponentNameTarget.textContent = this.opponentNameInputTarget.value || "対戦相手"
    }
  }

  updateFromActivePanel() {
    const activeTab = this.element.querySelector('[data-bs-toggle="tab"].active')
    if (!activeTab) return false

    const panelSelector = activeTab.dataset.bsTarget
    if (!panelSelector) return false

    const panel = this.element.querySelector(panelSelector)
    if (!panel) return false

    let playerTotal = 0
    let opponentTotal = 0

    panel.querySelectorAll('input[name*="[score]"]').forEach(input => {
      playerTotal += parseInt(input.value) || 0
    })
    panel.querySelectorAll('input[name*="[lost_score]"]').forEach(input => {
      opponentTotal += parseInt(input.value) || 0
    })

    if (this.hasPlayerPointsTarget) this.playerPointsTarget.textContent = playerTotal
    if (this.hasOpponentPointsTarget) this.opponentPointsTarget.textContent = opponentTotal

    const badge = activeTab.querySelector('.badge')
    if (badge) badge.textContent = `${playerTotal}-${opponentTotal}`

    const gameIdx = activeTab.dataset.gameIdx
    if (gameIdx !== undefined) {
      this.gameScores[gameIdx] = { player: playerTotal, opponent: opponentTotal }
      this.updateGameHistoryEntry(gameIdx, playerTotal, opponentTotal)
      this.updateWins()
    }

    return true
  }

  updateGameHistoryEntry(gameIdx, playerTotal, opponentTotal) {
    if (!this.hasGameHistoryTarget) return
    const entry = this.gameHistoryTarget.querySelector(`[data-game-idx="${gameIdx}"]`)
    if (!entry) return

    entry.textContent = `${playerTotal}-${opponentTotal}`
    entry.className = `game-score-result ${playerTotal > opponentTotal ? 'game-won' : 'game-lost'}`
  }

  updateWins() {
    let playerWins = 0
    let opponentWins = 0
    Object.values(this.gameScores).forEach(({ player, opponent }) => {
      if (player > opponent) playerWins++
      else if (opponent > player) opponentWins++
    })
    if (this.hasPlayerWinsTarget) this.playerWinsTarget.textContent = playerWins
    if (this.hasOpponentWinsTarget) this.opponentWinsTarget.textContent = opponentWins
  }

  changeFormat(event) {
    const format = parseInt(event.target.value)
    this.gameSlotTargets.forEach((slot, i) => {
      slot.classList.toggle('d-none', i >= format)
    })
  }

  update() {
    this.updateNames()

    if (this.updateFromActivePanel()) return

    let playerTotal = 0
    let opponentTotal = 0

    this.element.querySelectorAll('input[name*="[score]"]').forEach(input => {
      playerTotal += parseInt(input.value) || 0
    })
    this.element.querySelectorAll('input[name*="[lost_score]"]').forEach(input => {
      opponentTotal += parseInt(input.value) || 0
    })

    if (this.hasPlayerPointsTarget) this.playerPointsTarget.textContent = playerTotal
    if (this.hasOpponentPointsTarget) this.opponentPointsTarget.textContent = opponentTotal
  }
}
