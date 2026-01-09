import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "viewDivisions", "viewSpecs", "viewForm", "specListContainer", "modalTitle"]

  connect() {
    // Parse the big JSON blob of specs
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
    const divisionName = event.target.dataset.division;
    
    // Filter specs by division
    const specs = this.allSpecs.filter(s => s.division === divisionName);
    
    // Render list
    let html = "";
    specs.forEach(spec => {
      html += `
        <button type="button" class="list-item" 
                data-action="click->spec-drilldown#selectSpec" 
                data-id="${spec.id}">
          <strong>${spec.code}</strong> - ${spec.description}
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
    const specId = parseInt(event.target.closest("button").dataset.id);
    this.currentSpec = this.allSpecs.find(s => s.id === specId);
    
    // UPDATED: Pass empty object {} as second argument
    this.renderChecklistForm(this.currentSpec.checklist_questions, {});
    
    this.viewSpecsTarget.style.display = "none";
    this.viewFormTarget.style.display = "block";
    this.modalTitleTarget.innerText = `Checklist: ${this.currentSpec.code}`;
  }

  // NEW: Handle clicking the "Edit" button on an existing card
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
  // UPDATED: Now accepts 'savedAnswers' argument
  renderChecklistForm(questions, savedAnswers = {}) {
    const container = document.getElementById("checklist-form-placeholder");
    
    let html = `<div style="padding: 10px;">`;
    html += `<p style="margin-bottom: 20px;"><strong>${questions.length} items to check:</strong></p>`;
    
    questions.forEach((q) => {
      // Helper to check if this radio should be selected
      const isChecked = (val) => savedAnswers[q] === val ? "checked" : "";

      html += `
        <div class="checklist-item" style="margin-bottom: 15px; border-bottom: 1px solid #eee; padding-bottom: 10px;">
          <p style="margin: 0 0 5px 0;">${q}</p>
          <div style="display: flex; gap: 15px;">
            <label><input type="radio" name="answers[${q}]" value="Yes" ${isChecked("Yes")}> Yes</label>
            <label><input type="radio" name="answers[${q}]" value="No" ${isChecked("No")}> No</label>
            <label><input type="radio" name="answers[${q}]" value="N/A" ${isChecked("N/A")}> N/A</label>
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
    
    container.innerHTML = html;
  }
  
  saveChecklist(event) {
    const btn = event.target;
    btn.disabled = true;
    btn.innerText = "Saving...";

    // 1. Harvest Answers
    const answers = {};
    const formContainer = document.getElementById("checklist-form-placeholder");
    const radios = formContainer.querySelectorAll('input[type="radio"]:checked');
    
    radios.forEach(radio => {
      // name="answers[Does it work?]" -> key="Does it work?"
      const key = radio.name.match(/\[(.*?)\]/)[1]; 
      answers[key] = radio.value;
    });

    // 2. Identify Context
    // We need the Report ID. We can grab it from the main form action URL or a data attribute.
    const reportId = document.getElementById("report-form").action.split("/").pop(); // Simple URL parser
    
    // 3. Send to Server
    fetch(`/reports/${reportId}/checklist_entries`, {
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
        this.addBadgeToUI(data, answers); // Pass answers to update the UI data attribute
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
    
    // Remove "No checklists" message if it exists
    const emptyMsg = list.querySelector(".text-muted");
    if (emptyMsg) emptyMsg.remove();

    // Check if badge already exists (update scenario)
    let card = list.querySelector(`[data-spec-code="${data.spec_code}"]`);
    
    if (card) {
      // Update existing card's data-answers
      card.dataset.answers = JSON.stringify(newAnswers);
      // Flash effect to show update
      card.style.backgroundColor = "#ecfdf5";
      setTimeout(() => card.style.backgroundColor = "", 1000);
    } else {
      // Create new card HTML
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
      // Append to the grid
      if (!list.classList.contains("gallery-grid")) list.classList.add("gallery-grid");
      list.insertAdjacentHTML("beforeend", html);
    }
  }
}