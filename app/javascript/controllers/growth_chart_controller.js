import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js"

export default class extends Controller {
  static targets = ["canvas"]

  static values = {
    labels: String,
    data: String
  }

  connect() {
    if (!this.hasCanvasTarget) return

    const labels = this.parseJson(this.labelsValue, [])
    const data = this.parseJson(this.dataValue, [])

    this.chart = new Chart(this.canvasTarget, {
      type: "line",
      data: {
        labels: labels,
        datasets: [{
          label: "得点内訳における使用率（%）",
          data: data,
          borderColor: "#2e7d32",
          backgroundColor: "rgba(46, 125, 50, 0.15)",
          tension: 0.3,
          fill: true,
          pointRadius: 4
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: {
            beginAtZero: true,
            max: 100,
            ticks: { callback: (value) => `${value}%` }
          }
        },
        plugins: {
          legend: { display: false }
        }
      }
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  parseJson(value, fallback) {
    if (!value) return fallback
    try {
      const parsed = JSON.parse(value)
      return Array.isArray(parsed) ? parsed : fallback
    } catch (_e) {
      return fallback
    }
  }
}
