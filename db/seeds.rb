# db/seeds.rb

puts "🌱 Maestro: Cleaning old data..."
ChecklistEntry.destroy_all
PlacedQuantity.destroy_all
QaEntry.destroy_all
CrewEntry.destroy_all
EquipmentEntry.destroy_all
ReportAttachment.destroy_all
Report.destroy_all
BidItem.destroy_all
SpecItem.destroy_all
Project.destroy_all
Phase.destroy_all

puts "🏗️  Maestro: Building Projects..."
Project.create!(name: "Runway 1R Rehabilitation")
Project.create!(name: "Taxiway Z Rehabilitation")
Project.create!(name: "Gate 17 Apron Rehabilitation")

puts "📅 Maestro: Building Phases..."
(1..6).each { |i| Phase.create!(name: "Phase #{i}") }

puts "📘 Maestro: Building FAA Spec Library (AC 150/5370-10H)..."

# The FAA Master List
faa_specs = {
  "Part 2 – General Construction" => {
    "C-100" => "Contractor Quality Control Program (CQCP)",
    "C-102" => "Temporary Air and Water Pollution, Soil Erosion, and Siltation Control",
    "C-105" => "Mobilization",
    "C-110" => "Method of Estimating Percentage of Material Within Specification Limits (PWL)"
  },
  "Part 3 – Sitework" => {
    "P-101" => "Preparation/Removal of Existing Pavements",
    "P-151" => "Clearing and Grubbing",
    "P-152" => "Excavation, Subgrade, and Embankment",
    "P-153" => "Controlled Low-Strength Material (CLSM)",
    "P-154" => "Subbase Course",
    "P-155" => "Lime-Treated Subgrade",
    "P-156" => "Cement-Treated Subgrade",
    "P-157" => "Kiln Dust Treated Subgrade",
    "P-158" => "Fly Ash Treated Subgrade"
  },
  "Part 4 – Base Courses" => {
    "P-207" => "In-place Full Depth Reclamation (FDR) Base Course",
    "P-208" => "Aggregate Base Course",
    "P-209" => "Crushed Aggregate Base Course",
    "P-210" => "Caliche Base Course",
    "P-211" => "Lime Rock Base Course",
    "P-212" => "Shell Base Course",
    "P-213" => "Sand-Clay Base Course",
    "P-217" => "Aggregate-Turf Runway/Taxiway",
    "P-219" => "Recycled Concrete Aggregate Base Course",
    "P-220" => "Cement Treated Soil Base Course"
  },
  "Part 5 – Stabilized Base Courses" => {
    "P-304" => "Cement-Treated Aggregate Base Course (CTB)",
    "P-306" => "Lean Concrete Base Course",
    "P-307" => "Cement Treated Permeable Base Course (CTPB)"
  },
  "Part 6 – Flexible Pavements" => {
    "P-401" => "Asphalt Mix Pavement",
    "P-403" => "Asphalt Mix Pavement [Base/Leveling/Surface]",
    "P-404" => "Fuel-Resistant Asphalt Mix Pavement"
  },
  "Part 7 – Rigid Pavement" => {
    "P-501" => "Cement Concrete Pavement"
  },
  "Part 8 – Surface Treatments" => {
    "P-608" => "Emulsified Asphalt Seal Coat",
    "P-608-R" => "Rapid Cure Seal Coat",
    "P-609" => "Chip Seal Coat",
    "P-623" => "Emulsified Asphalt Spray Seal Coat",
    "P-626" => "Emulsified Asphalt Slurry Seal Surface Treatment",
    "P-629" => "Thermoplastic Coal Tar Emulsion Surface Treatments",
    "P-630" => "Refined Coal Tar Emulsion Without Additives",
    "P-631" => "Refined Coal Tar Emulsion With Additives",
    "P-632" => "Asphalt Pavement Rejuvenation"
  },
  "Part 9 – Miscellaneous" => {
    "P-602" => "Emulsified Asphalt Prime Coat",
    "P-603" => "Emulsified Asphalt Tack Coat",
    "P-604" => "Compression Joint Seals for Concrete Pavements",
    "P-605" => "Joint Sealants for Pavements",
    "P-606" => "Adhesive Compounds for Sealing Wire/Lights",
    "P-610" => "Concrete for Miscellaneous Structures",
    "P-620" => "Runway and Taxiway Marking",
    "P-621" => "Saw-Cut Grooves"
  },
  "Part 10 – Fencing" => {
    "F-160" => "Wire Fence with Wood Posts",
    "F-161" => "Wire Fence with Steel Posts",
    "F-162" => "Chain-Link Fence",
    "F-163" => "Wildlife Deterrent Fence Skirt",
    "F-164" => "Wildlife Exclusion Fence"
  },
  "Part 11 – Drainage" => {
    "D-701" => "Pipe for Storm Drains and Culverts",
    "D-702" => "Slotted Drains",
    "D-705" => "Pipe Underdrains for Airports",
    "D-751" => "Manholes, Catch Basins, Inlets",
    "D-752" => "Concrete Culverts and Headwalls",
    "D-754" => "Concrete Gutters, Ditches, and Flumes"
  },
  "Part 12 – Turfing" => {
    "T-901" => "Seeding",
    "T-903" => "Sprigging",
    "T-904" => "Sodding",
    "T-905" => "Topsoiling",
    "T-908" => "Mulching"
  },
  "Part 13 – Lighting Installation" => {
    "L-101" => "Airport Rotating Beacons",
    "L-103" => "Airport Beacon Towers",
    "L-107" => "Airport Wind Cones",
    "L-108" => "Underground Power Cable for Airports",
    "L-109" => "Airport Transformer Vault and Equipment",
    "L-110" => "Airport Underground Electrical Duct Banks",
    "L-115" => "Electrical Manholes and Junction Structures",
    "L-119" => "Airport Obstruction Lights",
    "L-125" => "Installation of Airport Lighting Systems"
  }
}

# Default Checklist Questions (Generic Placeholder)
default_questions = [
  "Material submittals approved?",
  "Weather conditions acceptable?",
  "Equipment clean and functional?",
  "Grade and alignment checked?",
  "Safety requirements met?",
  "Photos taken?"
]

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

puts "💰 Maestro: Linking Bid Items (Simulation)..."
# Randomly create some bid items for testing
["P-401", "P-403", "P-152", "P-620", "D-701", "L-108"].each do |code|
  spec = SpecItem.find_by(code: code)
  next unless spec
  
  BidItem.create!(
    code: "BID-#{code}-01",
    description: "Install #{spec.description}",
    unit: "EA",
    spec_item: spec
  )
end

puts "✅ Maestro: Seeding Complete!"
puts "   Specs Created: #{SpecItem.count}"
puts "   Divisions:     #{SpecItem.distinct.count(:division)}"