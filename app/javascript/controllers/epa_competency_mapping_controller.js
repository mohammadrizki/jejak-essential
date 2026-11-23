import { Controller } from "@hotwired/stimulus"

// Keeps an EPA mapping's indicator options aligned with the selected
// competency item while preserving a no-JavaScript server-side validation.
export default class extends Controller {
  static targets = ["competency", "indicator"]

  connect() {
    this.filterIndicators()
  }

  filterIndicators() {
    const competencyId = this.competencyTarget.value
    const select = this.indicatorTarget

    for (const option of select.querySelectorAll("option[data-competency-item-id]")) {
      option.hidden = Boolean(competencyId) && option.dataset.competencyItemId !== competencyId
    }

    for (const group of select.querySelectorAll("optgroup")) {
      group.hidden = !Array.from(group.options).some(option => !option.hidden)
    }

    const selected = select.selectedOptions[0]
    if (selected?.dataset.competencyItemId && selected.dataset.competencyItemId !== competencyId) {
      select.value = ""
    }
  }
}
