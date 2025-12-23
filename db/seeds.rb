# Clear out old data to avoid duplicates if we run this twice
BidItem.destroy_all
Project.destroy_all
Phase.destroy_all

puts "Seeding Database..."

# 1. Create Dummy Projects
p1 = Project.create!(name: "Segment 1 (Taxiway Z)")
p2 = Project.create!(name: "Segment 2 (Taxiway S)")

# 2. Create Dummy Phases
ph1 = Phase.create!(name: "Phase 1 - Earthwork")
ph2 = Phase.create!(name: "Phase 2 - Paving")

# 3. Create Dummy Bid Items
bid_items = [
  { code: "P-401", description: "Hot Mix Asphalt", unit: "TON" },
  { code: "P-403", description: "Base Course", unit: "CY" },
  { code: "D-701", description: "Storm Drain Pipe (24 in)", unit: "LF" },
  { code: "D-705", description: "Manhole Construction", unit: "EA" },
  { code: "M-100", description: "Mobilization", unit: "LS" }
]

bid_items.each do |item|
  BidItem.create!(item)
end

puts "Success! Created #{BidItem.count} bid items, #{Project.count} projects, and #{Phase.count} phases."