import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // These targets must match the data-spec-drilldown-target attributes in your HTML
  static targets = ["modal", "viewDivisions", "viewSpecs", "viewForm", "specListContainer", "modalTitle", "checklistFormPlaceholder"]
  
  // Captures the Report ID (if it exists)
  static values = { reportId: String }

  connect() {
    // 1. Load the spec data from the JSON script tag
    const dataScript = document.getElementById("spec-data-store");
    if (dataScript) {
      try {
        this.allSpecs = JSON.parse(dataScript.textContent);
        console.log("Maestro: Specs loaded successfully", this.allSpecs.length);
      } catch (e) {
        console.error("Maestro Error: Could not parse Spec JSON", e);
        this.allSpecs = [];
      }
    } else {
      console.warn("Maestro Warning: spec-data-store script not found.");
      this.allSpecs = [];
    }
    this.currentSpec = null;
  }

  // --- MODAL ACTIONS ---

  openModal() {
    console.log("Maestro: Opening Spec Modal");
    // Show the dialog
    this.modalTarget.showModal();
    // Reset to the first view (Divisions)
    this.showDivisions();
  }

  closeModal() {
    this.modalTarget.close();
  }

  // --- VIEW SWITCHING ---

  showDivisions() {
    this.viewDivisionsTarget.style.display = "block";
    this.viewSpecsTarget.style.display = "none";
    this.viewFormTarget.style.display = "none";
    this.modalTitleTarget.innerText = "Select Division";
  }
  
  showSpecs() {
    this.viewDivisionsTarget.style.display = "none";
    this.viewSpecsTarget.style.display = "block";
    this.viewFormTarget.style.display = "none";
  }

  // --- SELECTION LOGIC ---

  selectDivision(event) {
    // 1. Get the division name from the clicked button
    const divisionName = event.currentTarget.dataset.division;
    
    // 2. Filter specs
    const specs = this.allSpecs.filter(s => s.division === divisionName);
    
    // 3. Render the list of specs
    let html = "";
    specs.forEach(spec => {
      html += `
        <button type="button" class="spec-selection-btn" 
                data-action="click->spec-drilldown#selectSpec" 
                data-id="${spec.id}">
          <strong style="color: var(--primary);">${spec.code}</strong>
          <span class="text-muted-sm">${spec.description}</span>
        </button>
      `;
    });
    this.specListContainerTarget.innerHTML = html;
    
    // 4. Switch View
    this.modalTitleTarget.innerText = divisionName;
    this.showSpecs();
  }

  selectSpec(event) {
    const specId = parseInt(event.currentTarget.dataset.id);
    this.currentSpec = this.allSpecs.find(s => s.id === specId);
    
    // Pass empty object {} because this is a new checklist
    this.renderChecklistForm(this.currentSpec.checklist_questions, {});
    
    this.viewSpecsTarget.style.display = "none";
    this.viewFormTarget.style.display = "block";
    this.modalTitleTarget.innerText = `Checklist: ${this.currentSpec.code}`;
  }

  editSpec(event) {
    // Handle editing an existing card
    const card = event.target.closest(".gallery-card");
    const specId = parseInt(card.dataset.specId);
    const savedAnswers = JSON.parse(card.dataset.answers || "{}");
    
    this.currentSpec = this.allSpecs.find(s => s.id === specId);
    
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
      // Create a safe key for the HTML name attribute
      const safeKey = q.replace(/"/g, '&quot;');

      html += `
        <div class="checklist-item" style="margin-bottom: 15px; border-bottom: 1px solid var(--border-color); padding-bottom: 10px;">
          <p style="margin: 0 0 5px 0; font-size: 0.95rem;">${q}</p>
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
        <button type="button" class="btn btn-primary" data-action="click->spec-drilldown#saveChecklist">Save Checklist</button>
      </div>
    `;
    html += `</div>`;
    
    this.checklistFormPlaceholderTarget.innerHTML = html;
  }
  
  // --- SAVING LOGIC (The Critical Fix) ---

  saveChecklist(event) {
    const btn = event.target;
    btn.disabled = true;
    btn.innerText = "Saving...";

    // 1. Harvest Answers from the Radio Buttons
    const answers = {};
    const radios = this.checklistFormPlaceholderTarget.querySelectorAll('input[type="radio"]:checked');
    
    radios.forEach(radio => {
      const keyMatch = radio.name.match(/answers\[(.*?)\]/);
      if (keyMatch) {
        answers[keyMatch[1]] = radio.value;
      }
    });

    // 2. CHECK: Are we in "Draft Mode" (New Report) or "Edit Mode" (Saved Report)?
    if (!this.reportIdValue) {
      // --- DRAFT MODE: Inject Hidden Fields ---
      // We generate a unique ID so Rails knows this is a new nested record
      const uniqueId = new Date().getTime();
      
      const mockData = {
        spec_code: this.currentSpec.code,
        spec_desc: this.currentSpec.description,
        id: null 
      };
      
      this.addBadgeToUI(mockData, answers, uniqueId);
      this.closeModal();
      
      btn.disabled = false;
      btn.innerText = "Save Checklist";

    } else {
      // --- SAVED MODE: Use AJAX ---
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
          this.addBadgeToUI(data, answers, null);
          this.closeModal();
        } else {
          alert("Error saving: " + data.message);
        }
      })
      .catch(error => {
        console.error(error);
        alert("Network Error");
      })
      .finally(() => {
        btn.disabled = false;
        btn.innerText = "Save Checklist";
      });
    }
  }

  addBadgeToUI(data, newAnswers, newRecordId = null) {
    const list = document.getElementById("active-checklists-list");
    
    // Remove "No checklists" message
    const emptyMsg = list.querySelector(".spec-empty-state");
    if (emptyMsg) emptyMsg.remove();

    // Check if card already exists (Update vs Create)
    let card = list.querySelector(`[data-spec-code="${data.spec_code}"]`);
    
    if (card) {
      // UPDATE EXISTING
      card.dataset.answers = JSON.stringify(newAnswers);
      // Visual flash
      card.style.backgroundColor = "#ecfdf5";
      setTimeout(() => card.style.backgroundColor = "", 1000);
      
      // If it's a draft mode item, we should ideally update the hidden input too, 
      // but simpler to just let them delete and re-add for now in draft mode.
      if (newRecordId) {
         // Logic to update hidden field value would go here
         const hiddenInput = card.querySelector(`input[name*="[checklist_answers]"]`);
         if(hiddenInput) hiddenInput.value = JSON.stringify(newAnswers);
      }

    } else {
      // CREATE NEW
      let hiddenFields = "";
      
      // If NewRecordId is present, we are in Draft Mode -> Inject Hidden Inputs
      if (newRecordId) {
        hiddenFields = `
          <input type="hidden" name="report[checklist_entries_attributes][${newRecordId}][spec_item_id]" value="${this.currentSpec.id}">
          <input type="hidden" name="report[checklist_entries_attributes][${newRecordId}][checklist_answers]" value='${JSON.stringify(newAnswers)}'>
        `;
      }

      const html = `
        <div class="gallery-card" 
             style="padding: 15px; text-align: left;"
             data-spec-code="${data.spec_code}"
             data-spec-id="${data.id || ''}" 
             data-answers='${JSON.stringify(newAnswers)}'>
             
          ${hiddenFields}
             
          <div style="font-weight: bold; color: var(--primary); margin-bottom: 5px;">${data.spec_code}</div>
          <div class="text-muted-sm" style="margin-bottom: 10px; height: 40px; overflow: hidden;">${data.spec_desc}</div>
          
          <button type="button" 
                  class="btn-secondary w-full text-muted-sm"
                  data-action="click->spec-drilldown#editSpec">
             ✎ Edit Checklist
          </button>
        </div>
      `;
      list.insertAdjacentHTML("beforeend", html);
    }
  }
}