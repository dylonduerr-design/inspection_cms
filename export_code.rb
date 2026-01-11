# export_code.rb
# Run this with: ruby export_code.rb

# Directories to include recursively
INCLUDE_DIRS = %w[
  app
  config
  db
  lib
  public
]

# Specific files to include from the root
INCLUDE_FILES = %w[
  Gemfile
  config.ru
  package.json
]

# Extensions to process (skips images, binaries, etc.)
VALID_EXTENSIONS = %w[
  .rb .js .erb .html .css .scss .json .yml .yaml .sql .rake
]

# Directories/Files to ignore
IGNORE_PATHS = [
  'app/assets/images',
  'app/assets/builds',
  'config/credentials',
  'config/master.key',
  'db/schema.rb',
  'public/packs',
  'node_modules',
  'storage',
  'tmp',
  'log',
  '.git'
]

# --- MAESTRO: AUTO-INCREMENT LOGIC ---
# Scan directory for files matching "full_codebaserev*.txt"
existing_exports = Dir.glob('full_codebaserev*.txt')

# Extract numbers, default to 5 if none found (so next is 6)
max_rev = existing_exports.map { |f| f.scan(/\d+/).last.to_i }.max || 5
next_rev = max_rev + 1

OUTPUT_FILE = "full_codebaserev#{next_rev}.txt"
# -------------------------------------

def header(path)
  <<~HEADER
    
    
    ================================================================================
    FILE: #{path}
    ================================================================================
  HEADER
end

File.open(OUTPUT_FILE, 'w') do |out|
  # MAESTRO: Added Revision Number to Header
  out.puts "INSPECTION CMS CODEBASE EXPORT - REVISION #{next_rev} - #{Time.now}"
  
  # 1. Process specific root files
  INCLUDE_FILES.each do |file|
    next unless File.exist?(file)
    out.write header(file)
    out.write File.read(file)
  end

  # 2. Process directories
  INCLUDE_DIRS.each do |dir|
    Dir.glob("#{dir}/**/*").each do |path|
      next if File.directory?(path)
      next unless VALID_EXTENSIONS.include?(File.extname(path))
      
      # Skip ignored paths
      next if IGNORE_PATHS.any? { |ignore| path.include?(ignore) }

      begin
        content = File.read(path)
        out.write header(path)
        out.write content
      rescue => e
        puts "Skipping #{path}: #{e.message}"
      end
    end
  end
end

puts "✅ Codebase dumped to #{OUTPUT_FILE} (Rev #{next_rev})"