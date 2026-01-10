import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "viewDivisions", "viewSpecs", "viewForm", "specListContainer", "modalTitle", "checklistFormPlaceholder"]
  // NEW: Robustly capture the ID passed from the view
  static values = { reportId: String }

  connect() {
    // Parse the big JSON blob of specs once
    const dataScript = document.getElementById("spec-data-store");
    if (dataScript) {
      this.allSpecs = JSON.parse(dataScript.textContent);
    }
    this.currentSpec = null;
  }

  // --- NAVIGATION ---
  openModal() {
    this.modalTarget.showModal();
    this.showDivisions();
  }

  closeModal() {
    this.modalTarget.close();
  }

  showDivisions() {
    this.viewDivisionsTarget.style.display = "block";
    this.viewSpecsTarget.style.display = "none";
    this.viewFormTarget.style.display = "none";
    this.modalTitleTarget.innerText = "Select Division";
  }
  
  showSpecs() {
    this.viewSpecsTarget.style.display = "block";
    this.viewFormTarget.style.display = "none";
  }

  selectDivision(event) {
    const divisionName = event.currentTarget.dataset.division;
    
    // Filter specs by division
    const specs = this.allSpecs.filter(s => s.division === divisionName);

    // Render list
    let html = "";
    specs.forEach(spec => {
      html += `
        <button type="button" class="list-item" 
                style="width:100%; text-align:left; padding:12px; margin-bottom:8px; background:white; border:1px solid #ddd; border-radius:6px; cursor:pointer;"
                data-action="click->spec-drilldown#selectSpec" 
                data-id="${spec.id}">
          <strong style="color:#2563eb;">${spec.code}</strong><br>
          <span style="font-size:0.9em; color:#666;">${spec.description}</span>
        </button>
      `;
    });
    this.specListContainerTarget.innerHTML = html;
    
    // Switch Views
    this.viewDivisionsTarget.style.display = "none";
    this.viewSpecsTarget.style.display = "block";
    this.modalTitleTarget.innerText = divisionName;
  }

  selectSpec(event) {
    const specId = parseInt(event.currentTarget.dataset.id);
    this.currentSpec = this.allSpecs.find(s => s.id === specId);
    
    // Pass empty object {} for new checklists
    this.renderChecklistForm(this.currentSpec.checklist_questions, {});
    
    this.viewSpecsTarget.style.display = "none";
    this.viewFormTarget.style.display = "block";
    this.modalTitleTarget.innerText = `Checklist: ${this.currentSpec.code}`;
  }

  // Handle clicking the "Edit" button on an existing card
  editSpec(event) {
    const card = event.target.closest(".gallery-card");
    const specId = parseInt(card.dataset.specId);
    const savedAnswers = JSON.parse(card.dataset.answers || "{}");

    // Find the full spec object from our data store
    this.currentSpec = this.allSpecs.find(s => s.id === specId);

    // Open the modal directly to the form, passing the saved answers
    this.modalTarget.showModal();
    this.renderChecklistForm(this.currentSpec.checklist_questions, savedAnswers);
    
    this.viewDivisionsTarget.style.display = "none";
    this.viewSpecsTarget.style.display = "none";
    this.viewFormTarget.style.display = "block";
    this.modalTitleTarget.innerText = `Edit: ${this.currentSpec.code}`;
  }

  // --- FORM RENDERING ---
  renderChecklistForm(questions, savedAnswers = {}) {
    let html = `<div style="padding: 10px;">`;
    html += `<p style="margin-bottom: 20px;"><strong>${questions.length} items to check:</strong></p>`;
    
    questions.forEach((q) => {
      const isChecked = (val) => savedAnswers[q] === val ? "checked" : "";
      
      // Sanitized key for the name attribute
      const safeKey = q.replace(/"/g, '&quot;');

      html += `
        <div class="checklist-item" style="margin-bottom: 15px; border-bottom: 1px solid #eee; padding-bottom: 10px;">
          <p style="margin: 0 0 5px 0;">${q}</p>
          <div style="display: flex; gap: 15px;">
            <label><input type="radio" name="answers[${safeKey}]" value="Yes" ${isChecked("Yes")}> Yes</label>
            <label><input type="radio" name="answers[${safeKey}]" value="No" ${isChecked("No")}> No</label>
            <label><input type="radio" name="answers[${safeKey}]" value="N/A" ${isChecked("N/A")}> N/A</label>
          </div>
        </div>
      `;
    });

    html += `
      <div style="margin-top: 20px; text-align: right;">
        <button type="button" class="btn-primary-action" data-action="click->spec-drilldown#saveChecklist">Save Checklist</button>
      </div>
    `;
    html += `</div>`;
    
    this.checklistFormPlaceholderTarget.innerHTML = html;
  }
  
  saveChecklist(event) {
    const btn = event.target;
    btn.disabled = true;
    btn.innerText = "Saving...";

    // 1. Harvest Answers
    const answers = {};
    const radios = this.checklistFormPlaceholderTarget.querySelectorAll('input[type="radio"]:checked');
    
    radios.forEach(radio => {
      // Extract the original question key from the name attribute
      const keyMatch = radio.name.match(/answers\[(.*?)\]/);
      if (keyMatch) {
        // We decode HTML entities if necessary, but usually the raw string works here
        answers[keyMatch[1]] = radio.value;
      }
    });

    // 2. Identify Context (ROBUST FIX)
    if (!this.reportIdValue) {
       alert("Error: Missing Report ID. Cannot save.");
       return;
    }
    
    // 3. Send to Server
    fetch(`/reports/${this.reportIdValue}/checklist_entries`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({
        spec_item_id: this.currentSpec.id,
        answers: answers
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.status === "success") {
        this.addBadgeToUI(data, answers); 
        this.closeModal();
      } else {
        alert("Error saving: " + data.message);
        btn.disabled = false;
        btn.innerText = "Save Checklist";
      }
    })
    .catch(error => {
      console.error(error);
      alert("Network Error");
      btn.disabled = false;
    });
  }

  addBadgeToUI(data, newAnswers) {
    const list = document.getElementById("active-checklists-list");
    
    // Remove "No checklists" message
    const emptyMsg = list.querySelector(".text-muted");
    if (emptyMsg) emptyMsg.remove();

    // Check if badge already exists (update scenario)
    let card = list.querySelector(`[data-spec-code="${data.spec_code}"]`);
    
    if (card) {
      // Update existing card
      card.dataset.answers = JSON.stringify(newAnswers);
      card.style.backgroundColor = "#ecfdf5"; // Flash Green
      setTimeout(() => card.style.backgroundColor = "", 1000);
    } else {
      // Create new card
      const html = `
        <div class="gallery-card" 
             style="padding: 15px; text-align: left;"
             data-spec-code="${data.spec_code}"
             data-spec-id="${data.id}" 
             data-answers='${JSON.stringify(newAnswers)}'>
             
          <div style="font-weight: bold; color: var(--primary); margin-bottom: 5px;">${data.spec_code}</div>
          <div style="font-size: 0.85rem; color: var(--text-muted); margin-bottom: 10px; height: 40px; overflow: hidden;">${data.spec_desc}</div>
          
          <button type="button" 
                  class="btn-secondary" 
                  style="width: 100%; font-size: 0.8rem;"
                  data-action="click->spec-drilldown#editSpec">
             ✎ Edit Checklist
          </button>
        </div>
      `;
      // Ensure grid class exists
      if (!list.classList.contains("gallery-grid")) list.classList.add("gallery-grid");
      list.insertAdjacentHTML("beforeend", html);
    }
  }
}