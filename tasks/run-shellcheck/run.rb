#!/usr/bin/env ruby

require_relative 'shell-checker'

directory_to_check = ENV['DIRECTORY_TO_CHECK']

puts "Checking #{directory_to_check}"

shell_checker = ShellChecker.new.check_shell_files(directory: directory_to_check)

puts "Found #{shell_checker.size} shell files to inspect"
puts ''

count = 0

shell_checker.each do |file_path, shellcheck_output|
  unless shellcheck_output.empty?
    puts '########################################################################################'
    puts "## shellcheck results for #{file_path}"
    puts '########################################################################################'
    puts shellcheck_output
    count += 1
  end
end

puts ''

if count == 0
  puts 'Found no errors'
else
  puts "Found errors in #{count} out of #{shell_checker.size} files"
  exit 1
end
