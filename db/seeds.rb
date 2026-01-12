# db/seeds.rb

puts "🌱 Maestro: Cleaning old data..."
# We destroy child records first (explicitly) to keep the logs clean
ChecklistEntry.destroy_all
PlacedQuantity.destroy_all
QaEntry.destroy_all
CrewEntry.destroy_all
EquipmentEntry.destroy_all
ReportAttachment.destroy_all
Report.destroy_all
ActivityLog.destroy_all
BidItem.destroy_all
SpecItem.destroy_all
Project.destroy_all
Phase.destroy_all
User.destroy_all

puts "👤 Maestro: Creating Admin User..."
admin = User.create!(
  email: "admin@example.com",
  password: "password",
  password_confirmation: "password"
)

puts "🏗️  Maestro: Building Projects..."
project_1 = Project.find_or_create_by!(name: "Runway 1R Rehabilitation") do |p|
  p.contract_number = "8983.61"
  p.project_manager = "Anthony Lum, PE"
  p.construction_manager = "Joshua Alcantara, PE"
  p.contract_days = 89
  p.contract_start_date = Date.new(2025, 9, 24)
end

Project.find_or_create_by!(name: "Taxiway Z Rehabilitation") do |p|
  p.contract_number = "9000.12"
  p.project_manager = "Anthony Lum, PE"
  p.construction_manager = "Joshua Alcantara, PE"
  p.contract_days = 120
  p.contract_start_date = Date.new(2025, 10, 1)
end

puts "📅 Maestro: Building Phases..."
phase_1 = Phase.find_or_create_by!(name: "Phase 1 - Demolition")
(2..6).each { |i| Phase.find_or_create_by!(name: "Phase #{i}") }

puts "📘 Maestro: Building FAA Spec Library..."
default_questions = [
  "Material submittals approved?",
  "Weather conditions acceptable?",
  "Equipment clean and functional?",
  "Grade and alignment checked?",
  "Safety requirements met?",
  "Photos taken?"
]

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

puts "💰 Maestro: Linking Bid Items..."
# We keep track of these to use in the sample report
p401_bid_item = nil 

["P-401", "P-403", "P-152", "P-620"].each do |code|
  spec = SpecItem.find_by(code: code)
  next unless spec
  
  bid_item = BidItem.create!(
    project: project_1,
    code: "BID-#{code}-01",
    description: "Install #{spec.description}",
    unit: "EA",
    spec_item: spec,
    checklist_questions: spec.checklist_questions
  )

  # Capture P-401 for our sample report
  p401_bid_item = bid_item if code == "P-401"
end

puts "📝 Maestro: Generating Sample Report..."
report = Report.create!(
  user: admin,
  project: project_1,
  phase: phase_1,
  dir_number: "001",
  start_date: Date.today,
  status: :creating,   # Enum: creating
  result: :pending,    # Enum: pending
  shift_start: "07:00",
  shift_end: "15:30",
  contractor: "Granite Construction",
  
  # Weather (Just filling a few for the dashboard)
  temp_1: 65, weather_summary_1: "Clear", wind_1: "5mph N",
  temp_2: 72, weather_summary_2: "Sunny", wind_2: "8mph NW",
  
  commentary: "First day of paving operations. Crew arrived on time. Safety briefing conducted."
)

puts "👷 Maestro: Populating Crew Log (Using NEW Schema)..."
# This tests our integer migration
CrewEntry.create!(
  report: report,
  contractor: "Granite Construction",
  superintendent_count: 1,  # <--- New Integer Field
  foreman_count: 2,         # <--- New Integer Field
  operator_count: 4,
  laborer_count: 6,
  notes: "Paving crew and prep team."
)

puts "🚜 Maestro: Populating Equipment..."
EquipmentEntry.create!(
  report: report,
  contractor: "Granite Construction",
  make_model: "Cat AP1000 Paver",
  quantity: 1,
  hours: 8
)

if p401_bid_item
  puts "📊 Maestro: Adding Quantities..."
  PlacedQuantity.create!(
    report: report,
    bid_item: p401_bid_item,
    quantity: 500.0,
    location: "Sta 10+00 to 15+00",
    notes: "Mainline paving pass 1",
    checklist_answers: { "Material submittals approved?" => "Yes", "Safety requirements met?" => "Yes" }
  )
end

puts "✅ Maestro: Seeding Complete!"
puts "   User: admin@example.com / password"
puts "   Project: #{project_1.name}"
puts "   Report: DIR #001 Created with Crew & Equipment"