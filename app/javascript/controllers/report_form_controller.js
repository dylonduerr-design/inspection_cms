import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checklistModal", "questionsContainer"]

  connect() {
    this.currentHiddenInput = null;
    this.currentQuestions = [];

    // ON LOAD: Wake up all existing rows (for Edit/Show pages)
    // This finds every bid item dropdown and manually runs the logic to set up its button
    this.element.querySelectorAll("select[name*='bid_item_id']").forEach(select => {
      this.updateRowState(select);
    });
  }

  // 1. TRIGGER: Dropdown Change
  selectBidItem(event) {
    this.updateRowState(event.target);
  }

  // HELPER: Handles the logic for a single row (used by Connect and Select)
  updateRowState(select) {
    const row = select.closest(".nested-fields");
    if (!row) return;

    const button = row.querySelector(".checklist-btn");
    const hiddenInput = row.querySelector(".checklist-answers-field");
    const selectedOption = select.options[select.selectedIndex];

    // Safety check: If no option selected or no questions, disable
    if (!selectedOption || !selectedOption.dataset.questions) {
      this.disableButton(button);
      return;
    }

    const questionsJson = selectedOption.dataset.questions;

    if (questionsJson && questionsJson !== "[]") {
      const questions = JSON.parse(questionsJson);
      
      // Store questions on the button for later use
      button.dataset.questions = JSON.stringify(questions);
      button.disabled = false;
      button.classList.remove("opacity-50", "cursor-not-allowed");

      // SMART CHECK: Do we already have answers saved?
      const existingAnswers = hiddenInput.value ? JSON.parse(hiddenInput.value) : {};
      const hasAnswers = Object.keys(existingAnswers).length > 0;

      if (hasAnswers) {
        button.innerText = "✓ Edit Checklist";
        button.classList.add("text-success"); // Adds green styling if you have that class
        button.style.color = "green";         // Fallback inline style
      } else {
        button.innerText = "Open Checklist (" + questions.length + ")";
        button.classList.remove("text-success");
        button.style.color = "";
      }
    } else {
      this.disableButton(button);
    }
  }

  disableButton(button) {
    delete button.dataset.questions;
    button.disabled = true;
    button.classList.add("opacity-50", "cursor-not-allowed");
    button.innerText = "Open Checklist";
    button.style.color = "";
  }

  // 2. TRIGGER: Open Modal
  openChecklist(event) {
    event.preventDefault();
    const button = event.target;
    const row = button.closest(".nested-fields");
    
    // Store context for saving later
    this.currentHiddenInput = row.querySelector(".checklist-answers-field");
    
    // Parse questions and existing answers
    const questions = JSON.parse(button.dataset.questions || "[]");
    // CRITICAL: We read the value directly from the hidden input, which Rails populated on page load
    const existingAnswers = JSON.parse(this.currentHiddenInput.value || "{}");

    // Build Modal HTML
    let html = '<div style="display: flex; flex-direction: column; gap: 10px;">';
    
    questions.forEach((q, index) => {
      // Pre-check the radio buttons based on existing answers
      const yesChecked = existingAnswers[q] === "Yes" ? "checked" : "";
      const noChecked = existingAnswers[q] === "No" ? "checked" : "";
      const naChecked = existingAnswers[q] === "N/A" ? "checked" : "";

      html += `
        <div class="checklist-item" style="padding: 10px; background: #f8f9fa; border-radius: 5px;">
          <p style="margin: 0 0 5px 0; font-weight: 500;">${q}</p>
          <div style="display: flex; gap: 15px;">
            <label><input type="radio" name="q_${index}" value="Yes" ${yesChecked}> Yes</label>
            <label><input type="radio" name="q_${index}" value="No" ${noChecked}> No</label>
            <label><input type="radio" name="q_${index}" value="N/A" ${naChecked}> N/A</label>
          </div>
        </div>
      `;
    });
    
    html += '</div>';

    this.questionsContainerTarget.innerHTML = html;
    this.checklistModalTarget.showModal();
    this.currentQuestions = questions;
  }

  // 3. TRIGGER: Save
  saveChecklist(event) {
    event.preventDefault();
    
    const answers = {};
    const modalBody = this.questionsContainerTarget;
    
    this.currentQuestions.forEach((question, index) => {
      const selected = modalBody.querySelector(`input[name="q_${index}"]:checked`);
      if (selected) {
        answers[question] = selected.value;
      }
    });

    if (this.currentHiddenInput) {
      // Save to hidden field
      this.currentHiddenInput.value = JSON.stringify(answers);
      
      // Update UI immediately
      const row = this.currentHiddenInput.closest(".nested-fields");
      const select = row.querySelector("select");
      this.updateRowState(select); // Re-run logic to add the checkmark
    }

    this.closeModal();
  }

  closeModal() {
    this.checklistModalTarget.close();
    this.currentHiddenInput = null;
    this.currentQuestions = [];
  }
}