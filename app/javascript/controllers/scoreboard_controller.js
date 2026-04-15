import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "playerName", "opponentName",
    "playerPoints", "opponentPoints",
    "playerWins", "opponentWins",
    "gameHistory",
    "playerNameInput", "opponentNameInput"
  ]

  connect() {
    // すべてのnumber inputにイベントリスナーを追加
    const numberInputs = this.element.querySelectorAll('input[type="number"]')
    numberInputs.forEach(input => {
      input.addEventListener('input', () => this.update())
    })

    this.update()
  }

  updateNames() {
    if (this.hasPlayerNameInputTarget && this.hasPlayerNameTarget) {
      this.playerNameTarget.textContent = this.playerNameInputTarget.value || "選手名"
    }
    if (this.hasOpponentNameInputTarget && this.hasOpponentNameTarget) {
      this.opponentNameTarget.textContent = this.opponentNameInputTarget.value || "対戦相手"
    }
  }

  update() {
    this.updateNames()

    // すべてのscoreとlost_scoreの値を合計
    let playerTotal = 0
    let opponentTotal = 0

    const scoreInputs = this.element.querySelectorAll('input[name*="[score]"]')
    const lostScoreInputs = this.element.querySelectorAll('input[name*="[lost_score]"]')

    scoreInputs.forEach(input => {
      playerTotal += parseInt(input.value) || 0
    })

    lostScoreInputs.forEach(input => {
      opponentTotal += parseInt(input.value) || 0
    })

    // 得点数のみを更新（ゲーム数とゲームスコアは固定）
    this.renderScoreboard(playerTotal, opponentTotal)
  }

  simulateGame(pRatio) {
    let p = 0, o = 0
    const target = 11
    let currentError = 0

    // Bresenhamアルゴリズムで点数を分配
    let totalPoints = 0
    const maxPoints = 200 // 安全のための上限

    while (totalPoints < maxPoints) {
      currentError += pRatio

      if (currentError >= 0.5) {
        p++
        currentError -= 1
      } else {
        o++
      }

      totalPoints++

      // デュース処理: 両者が10点以上で2点差がついたら終了
      if (p >= target && p - o >= 2) break
      if (o >= target && o - p >= 2) break
    }

    return { p, o }
  }

  simulateMatch(playerTotal, opponentTotal, maxGames) {
    const total = playerTotal + opponentTotal
    if (total === 0) {
      return { playerWins: 0, opponentWins: 0, games: [] }
    }

    const pRatio = playerTotal / total
    const winsNeeded = Math.ceil(maxGames / 2)

    let playerWins = 0
    let opponentWins = 0
    const games = []

    while (playerWins < winsNeeded && opponentWins < winsNeeded) {
      const game = this.simulateGame(pRatio)
      games.push(game)

      if (game.p > game.o) {
        playerWins++
      } else {
        opponentWins++
      }
    }

    return { playerWins, opponentWins, games }
  }

  renderScoreboard(playerTotal, opponentTotal) {
    // 合計得点のみを表示（ゲーム数とゲームスコアは更新しない）
    if (this.hasPlayerPointsTarget) {
      this.playerPointsTarget.textContent = playerTotal
    }
    if (this.hasOpponentPointsTarget) {
      this.opponentPointsTarget.textContent = opponentTotal
    }
  }
}
