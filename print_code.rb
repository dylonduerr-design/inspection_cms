# print_code.rb

# 1. Config: Which folders do you want to scan?
TARGET_FOLDERS = ['app', 'config', 'db', 'lib', 'Gemfile']

# 2. Config: Which file extensions should we read?
ALLOWED_EXTENSIONS = ['.rb', '.erb', '.html', '.js', '.css', '.scss', '.yml', '.sql', '.rake']

# 3. Config: Files or folders to explicitly ignore
IGNORE_LIST = [
  'node_modules', 'tmp', 'log', 'public', 'storage', 'vendor', 
  '.git', 'master.key', 'credentials.yml.enc'
  # Removed 'schema.rb' from here so it gets included!
]

OUTPUT_FILE = 'full_codebase.txt'

File.open(OUTPUT_FILE, 'w') do |output|
  # Iterate over each target folder/file
  TARGET_FOLDERS.each do |target|
    next unless File.exist?(target)

    # If it's just a file (like Gemfile), print it directly
    if File.file?(target)
      output.puts "=" * 50
      output.puts "FILE: #{target}"
      output.puts "=" * 50
      output.puts File.read(target)
      output.puts "\n\n"
      next
    end

    # If it's a directory, walk through it recursively
    Dir.glob("#{target}/**/*").each do |file_path|
      # Skip directories, only read files
      next if File.directory?(file_path)
      
      # Skip ignored paths
      next if IGNORE_LIST.any? { |ignore| file_path.include?(ignore) }

      # Check extension
      next unless ALLOWED_EXTENSIONS.include?(File.extname(file_path)) || File.basename(file_path) == 'Gemfile'

      begin
        content = File.read(file_path)
        
        # Write the header nicely so you know what file this is
        output.puts "=" * 80
        output.puts "FILE: #{file_path}"
        output.puts "=" * 80
        output.puts content
        output.puts "\n\n" # Extra spacing between files
        
        puts "Added: #{file_path}"
      rescue => e
        puts "Could not read #{file_path}: #{e.message}"
      end
    end
  end
end

puts "Done! All code (including Schema) saved to #{OUTPUT_FILE}"
