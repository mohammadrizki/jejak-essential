import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["version", "panel"]

  connect() {
    this.sync()
  }

  change() {
    this.sync()
  }

  sync() {
    const selectedId = this.versionTarget.value
    this.panelTargets.forEach((panel) => {
      const selected = panel.dataset.versionId === selectedId
      panel.hidden = !selected
      panel.querySelectorAll("input, select, textarea").forEach((field) => {
        field.disabled = !selected
      })
    })
  }
}
