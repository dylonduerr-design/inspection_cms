# db/seeds.rb

puts "🌱 Maestro: Cleaning old data..."
# We destroy child records first to avoid foreign key errors
ChecklistEntry.destroy_all
PlacedQuantity.destroy_all
QaEntry.destroy_all
CrewEntry.destroy_all
EquipmentEntry.destroy_all
ReportAttachment.destroy_all
Report.destroy_all
BidItem.destroy_all   # Now depends on Project
SpecItem.destroy_all
Project.destroy_all
Phase.destroy_all

puts "🏗️  Maestro: Building Projects (The Libraries)..."
# We now include the required Contract Info 
project_1 = Project.create!(
  name: "Runway 1R Rehabilitation",
  contract_number: "8983.61",
  project_manager: "Anthony Lum, PE",
  construction_manager: "Joshua Alcantara, PE",
  contract_days: 89,
  contract_start_date: Date.new(2025, 9, 24)
)

Project.create!(
  name: "Taxiway Z Rehabilitation",
  contract_number: "9000.12",
  project_manager: "Anthony Lum, PE",
  construction_manager: "Joshua Alcantara, PE",
  contract_days: 120,
  contract_start_date: Date.new(2025, 10, 1)
)

Project.create!(
  name: "Gate 17 Apron Rehabilitation",
  contract_number: "7555.05",
  project_manager: "Sarah Engineer, PE",
  construction_manager: "Mike Builder",
  contract_days: 45,
  contract_start_date: Date.new(2026, 1, 15)
)

puts "📅 Maestro: Building Phases..."
(1..6).each { |i| Phase.create!(name: "Phase #{i}") }

puts "📘 Maestro: Building FAA Spec Library (AC 150/5370-10H)..."

# Default Checklist Questions
default_questions = [
  "Material submittals approved?",
  "Weather conditions acceptable?",
  "Equipment clean and functional?",
  "Grade and alignment checked?",
  "Safety requirements met?",
  "Photos taken?"
]

# The FAA Master List (Simplified for Seed)
faa_specs = {
  "Part 6 – Flexible Pavements" => {
    "P-401" => "Asphalt Mix Pavement",
    "P-403" => "Asphalt Mix Pavement [Base/Leveling/Surface]",
  },
  "Part 3 – Sitework" => {
    "P-152" => "Excavation, Subgrade, and Embankment",
  },
  "Part 9 – Miscellaneous" => {
    "P-620" => "Runway and Taxiway Marking",
    "P-603" => "Emulsified Asphalt Tack Coat"
  },
  "Part 11 – Drainage" => {
    "D-701" => "Pipe for Storm Drains and Culverts"
  },
  "Part 13 – Lighting Installation" => {
    "L-108" => "Underground Power Cable for Airports"
  }
}

faa_specs.each do |division, items|
  items.each do |code, desc|
    SpecItem.create!(
      code: code,
      description: desc,
      division: division,
      checklist_questions: default_questions
    )
  end
end

puts "💰 Maestro: Linking Bid Items (The Translation Layer)..."

# We link specific codes (e.g. "BID-P-401-01") to Project 1
# This simulates the "Project Library" concept
["P-401", "P-403", "P-152", "P-620", "D-701", "L-108"].each do |code|
  spec = SpecItem.find_by(code: code)
  next unless spec
  
  BidItem.create!(
    project: project_1,            # <--- The Critical Link
    code: "BID-#{code}-01",        # The Project-Specific Code
    description: "Install #{spec.description}",
    unit: "EA",
    spec_item: spec,               # <--- The Universal Definition
    checklist_questions: spec.checklist_questions
  )
end

puts "✅ Maestro: Seeding Complete!"
puts "   Projects Created: #{Project.count}"
puts "   Bid Items (Project 1): #{project_1.bid_items.count}"