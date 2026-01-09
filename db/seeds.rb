# db/seeds.rb

puts "🌱 Maestro: Cleaning old data..."
# Use destroy_all to ensure callbacks run and dependent data is cleaned
PlacedQuantity.destroy_all # Clean the child records first
BidItem.destroy_all
SpecItem.destroy_all
Project.destroy_all
Phase.destroy_all

puts "🏗️  Maestro: Building Projects..."
projects = [
  "Runway 1R Rehabilitation", 
  "Taxiway Z Rehabilitation", 
  "Taxiway F Construction", 
  "Runway 10L Crack Repair", 
  "Gate 17 Apron Rehabilitation"
]
projects.each { |name| Project.create!(name: name) }

puts "📅 Maestro: Building Phases..."
(1..6).each { |i| Phase.create!(name: "Phase #{i}") }

puts "📘 Maestro: Building FAA Spec Items..."
# We add some default checklist questions to these so you can test the "Traffic Cop"
default_questions = [
  "Material certifications on file?",
  "Weather conditions within limits?",
  "Surface preparation accepted?",
  "Equipment approved?"
]

spec_codes = %w[
  P-101 P-151 P-152 P-153 P-156 
  P-207 P-208 P-209 P-210 P-211 P-212 P-213 P-217 P-219 P-220 
  P-304 P-306 P-307 
  P-401 P-403 
  P-602 P-603 P-605 P-606 P-608 P-610 P-620
]

spec_objects = []
spec_codes.each do |code|
  spec_objects << SpecItem.create!(
    code: code, 
    description: "FAA Specification #{code}",
    checklist_questions: default_questions
  )
end

puts "💰 Maestro: Building Bid Items..."
bid_codes = %w[
  BC-001 BC-102 BC-203 BC-304 BC-405 BC-506 
  BC-607 BC-708 BC-809 BC-910 BC-011
]

bid_codes.each do |code|
  # We randomly assign a Spec to each Bid Item to demo the relationship.
  # In real life, you would edit this to match the specific engineering logic.
  random_spec = spec_objects.sample
  
  BidItem.create!(
    code: code,
    description: "Bid Item for #{random_spec.code} work",
    unit: ["LS", "SY", "CY", "TON", "LF", "EA"].sample,
    spec_item: random_spec,
    checklist_questions: [] # We leave this empty to force it to use the Spec's questions
  )
end

puts "✅ Maestro: Seeding Complete!"
puts "   Projects: #{Project.count}"
puts "   Phases:   #{Phase.count}"
puts "   Specs:    #{SpecItem.count}"
puts "   BidItems: #{BidItem.count}"