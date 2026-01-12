# db/seeds.rb

puts "🌱 Maestro: Cleaning old data..."
ApprovedEquipment.destroy_all
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

puts "👤 Maestro: Creating Users..."
admin = User.create!(
  email: "admin@cms.com",
  password: "cloudattack",
  password_confirmation: "cloudattack"
)

tester = User.create!(
  email: "tester@cms.com",
  password: "cloudattack",
  password_confirmation: "cloudattack"
)

puts "🏗️  Maestro: Building Projects..."
project_1 = Project.find_or_create_by!(name: "Runway 1R Rehabilitation") do |p|
  p.contract_number = "8983.61"
  p.prime_contractor = "Granite Construction Company"
  p.project_manager = "Anthony Lum, PE"
  p.construction_manager = "Joshua Alcantara, PE"
  p.contract_days = 89
  p.contract_start_date = Date.new(2025, 9, 24)
end

project_2 = Project.find_or_create_by!(name: "Taxiway Charlie Reconstruction") do |p|
  p.contract_number = "9001.45"
  p.prime_contractor = "Flatiron Construction Corp"
  p.project_manager = "Sarah Martinez, PE"
  p.construction_manager = "David Chen, PE"
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
  "Part 1 – General Provisions" => {
    "P-101" => "Mobilization",
    "P-102" => "Seeding and Mulching",
  },
  "Part 2 – Earthwork and Drainage" => {
    "P-209" => "Aggregate Base Course",
    "P-210" => "Aggregate Drainage Course",
  },
  "Part 3 – Sitework" => {
    "P-152" => "Excavation, Subgrade, and Embankment",
    "P-154" => "Soil Stabilization with Portland Cement",
  },
  "Part 4 – Rigid Pavements" => {
    "P-501" => "Portland Cement Concrete Pavement",
    "P-502" => "Continuously Reinforced Portland Cement Concrete Pavement",
  },
  "Part 5 – Stabilized Pavements" => {
    "P-304" => "Aggregate Stabilization",
    "P-306" => "Cement Treated Base Course",
  },
  "Part 6 – Flexible Pavements" => {
    "P-401" => "Asphalt Mix Pavement",
    "P-403" => "Asphalt Mix Pavement [Base/Leveling/Surface]",
  },
  "Part 7 – Drainage and Utilities" => {
    "P-253" => "Storm Drainage Pipe",
    "P-254" => "Drainage Structures and Appurtenances",
  },
  "Part 8 – Lighting and Electrical" => {
    "P-610" => "Airfield Lighting Cable",
    "P-611" => "Airfield Lighting Equipment",
  },
  "Part 9 – Miscellaneous" => {
    "P-620" => "Runway and Taxiway Marking",
    "P-603" => "Emulsified Asphalt Tack Coat",
    "P-625" => "Pavement Grooving",
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
p401_bid_item = nil
p501_bid_item = nil

puts "   → Project 1 Bid Items (All Divisions)..."
faa_specs.each do |division, items|
  items.each do |code, desc|
    spec = SpecItem.find_by(code: code)
    next unless spec
    
    bid_item = BidItem.create!(
      project: project_1,
      code: "RW1R-#{code}",
      description: spec.description,
      unit: case code
            when "P-401", "P-403", "P-501", "P-502" then "SY"
            when "P-152", "P-209", "P-210", "P-304", "P-306" then "CY"
            when "P-620", "P-625", "P-610" then "LF"
            when "P-101" then "LS"
            else "EA"
            end,
      spec_item: spec,
      checklist_questions: spec.checklist_questions
    )
    
    p401_bid_item = bid_item if code == "P-401"
  end
end

puts "   → Project 2 Bid Items (All Divisions)..."
faa_specs.each do |division, items|
  items.each do |code, desc|
    spec = SpecItem.find_by(code: code)
    next unless spec
    
    bid_item = BidItem.create!(
      project: project_2,
      code: "TWC-#{code}",
      description: spec.description,
      unit: case code
            when "P-401", "P-403", "P-501", "P-502" then "SY"
            when "P-152", "P-209", "P-210", "P-304", "P-306" then "CY"
            when "P-620", "P-625", "P-610" then "LF"
            when "P-101" then "LS"
            else "EA"
            end,
      spec_item: spec,
      checklist_questions: spec.checklist_questions
    )
    
    p501_bid_item = bid_item if code == "P-501"
  end
end

puts "🛠️  Maestro: Adding Approved Equipment to Projects..."
["Caterpillar D6 Dozer", "Volvo L120 Loader", "John Deere 850K Dozer", 
 "Caterpillar AP1000 Paver", "Wirtgen W210 Cold Mill", "Bomag BW213 Roller"].each do |equipment|
  ApprovedEquipment.create!(project: project_1, name: equipment)
end

["Caterpillar 320 Excavator", "Terex TA400 Haul Truck", "Hamm HD120 Roller",
 "Caterpillar AP600 Paver", "Roadtec RX700e Paver", "Bomag BW177 Roller"].each do |equipment|
  ApprovedEquipment.create!(project: project_2, name: equipment)
end

puts "📝 Maestro: Generating Sample Report for Project 1..."
report = Report.create!(
  user: admin,
  project: project_1,
  phase: phase_1,
  dir_number: "001",
  start_date: Date.today,
  status: :creating,
  result: :pending,
  shift_start: "07:00",
  shift_end: "15:30",
  contractor: "Granite Construction Company",
  
  temp_1: 65, weather_summary_1: "Clear", wind_1: "5mph N",
  temp_2: 72, weather_summary_2: "Sunny", wind_2: "8mph NW",
  
  commentary: "First day of paving operations. Crew arrived on time. Safety briefing conducted."
)

CrewEntry.create!(
  report: report,
  contractor: "Granite Construction Company",
  superintendent_count: 1,
  foreman_count: 2,
  operator_count: 4,
  laborer_count: 6,
  notes: "Paving crew and prep team."
)

EquipmentEntry.create!(
  report: report,
  contractor: "Granite Construction Company",
  make_model: "Caterpillar AP1000 Paver",
  quantity: 1,
  hours: 8
)

if p401_bid_item
  PlacedQuantity.create!(
    report: report,
    bid_item: p401_bid_item,
    quantity: 500.0,
    location: "Sta 10+00 to 15+00",
    notes: "Mainline paving pass 1",
    checklist_answers: { "Material submittals approved?" => "Yes", "Safety requirements met?" => "Yes" }
  )
end

puts "📋 Maestro: Creating Sample Report for Project 2..."
report_2 = Report.create!(
  user: admin,
  project: project_2,
  phase: phase_1,
  dir_number: "002",
  start_date: Date.today - 5.days,
  status: :qc_review,
  result: :pass,
  shift_start: "06:00",
  shift_end: "14:30",
  contractor: "Flatiron Construction Corp",
  
  temp_1: 58, weather_summary_1: "Partly Cloudy", wind_1: "10mph SW",
  temp_2: 68, weather_summary_2: "Clear", wind_2: "12mph W",
  
  commentary: "Concrete paving operations proceeding on schedule. QC tests all passing."
)

CrewEntry.create!(
  report: report_2,
  contractor: "Flatiron Construction Corp",
  superintendent_count: 1,
  foreman_count: 1,
  operator_count: 3,
  laborer_count: 8,
  notes: "Concrete paving crew."
)

EquipmentEntry.create!(
  report: report_2,
  contractor: "Flatiron Construction Corp",
  make_model: "Caterpillar 320 Excavator",
  quantity: 2,
  hours: 7.5
)

if p501_bid_item
  PlacedQuantity.create!(
    report: report_2,
    bid_item: p501_bid_item,
    quantity: 350.0,
    location: "Sta 5+00 to 8+50",
    notes: "PCC pavement placement",
    checklist_answers: { "Material submittals approved?" => "Yes", "Grade and alignment checked?" => "Yes" }
  )
end

puts "📋 Maestro: Creating Reports for Tester User..."
phase_2 = Phase.find_by(name: "Phase 2")
p209_bid_item = BidItem.find_by(project: project_1, code: "RW1R-P-209")

report_3 = Report.create!(
  user: tester,
  project: project_1,
  phase: phase_2,
  dir_number: "003",
  start_date: Date.today - 2.days,
  status: :creating,
  result: :pending,
  shift_start: "06:30",
  shift_end: "15:00",
  contractor: "Granite Construction Company",
  
  temp_1: 62, weather_summary_1: "Overcast", wind_1: "8mph NE",
  temp_2: 70, weather_summary_2: "Partly Cloudy", wind_2: "10mph E",
  
  commentary: "Base course installation progressing. Weather conditions good for placement."
)

CrewEntry.create!(
  report: report_3,
  contractor: "Granite Construction Company",
  superintendent_count: 1,
  foreman_count: 1,
  operator_count: 5,
  laborer_count: 7,
  notes: "Base course crew."
)

EquipmentEntry.create!(
  report: report_3,
  contractor: "Granite Construction Company",
  make_model: "Volvo L120 Loader",
  quantity: 2,
  hours: 7.5
)

if p209_bid_item
  PlacedQuantity.create!(
    report: report_3,
    bid_item: p209_bid_item,
    quantity: 450.0,
    location: "Sta 20+00 to 25+00",
    notes: "Aggregate base placement",
    checklist_answers: { "Material submittals approved?" => "Yes", "Equipment clean and functional?" => "Yes" }
  )
end

p152_bid_item = BidItem.find_by(project: project_2, code: "TWC-P-152")

report_4 = Report.create!(
  user: tester,
  project: project_2,
  phase: phase_2,
  dir_number: "004",
  start_date: Date.today - 1.day,
  status: :revise,
  result: :pending,
  shift_start: "07:00",
  shift_end: "16:00",
  contractor: "Flatiron Construction Corp",
  
  temp_1: 55, weather_summary_1: "Clear", wind_1: "6mph W",
  temp_2: 66, weather_summary_2: "Sunny", wind_2: "9mph SW",
  
  commentary: "Excavation and grading operations. Minor grading adjustments requested by QC."
)

CrewEntry.create!(
  report: report_4,
  contractor: "Flatiron Construction Corp",
  superintendent_count: 1,
  foreman_count: 2,
  operator_count: 4,
  laborer_count: 5,
  notes: "Excavation and grading crew."
)

EquipmentEntry.create!(
  report: report_4,
  contractor: "Flatiron Construction Corp",
  make_model: "Terex TA400 Haul Truck",
  quantity: 3,
  hours: 8
)

if p152_bid_item
  PlacedQuantity.create!(
    report: report_4,
    bid_item: p152_bid_item,
    quantity: 620.0,
    location: "Sta 15+00 to 22+00",
    notes: "Excavation for subgrade prep",
    checklist_answers: { "Grade and alignment checked?" => "Yes", "Safety requirements met?" => "Yes" }
  )
end

puts "✅ Maestro: Seeding Complete!"
puts "   Users:"
puts "     - admin@cms.com / cloudattack"
puts "     - tester@cms.com / cloudattack"
puts "   Projects: 2 (#{project_1.name}, #{project_2.name})"
puts "   Spec Divisions: #{faa_specs.keys.count} (all represented in both projects)"
puts "   Bid Items: #{BidItem.count} total"
puts "   Approved Equipment: #{ApprovedEquipment.count} items across projects"
puts "   Reports: 4 sample reports created (2 per user)"
