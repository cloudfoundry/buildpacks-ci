#!/usr/bin/env ruby

Dir.chdir('binary-builder') do
  specs_on_filesystem = Dir['spec/integration/*_spec.rb'].map{|file| File.basename(file) }
  specs_in_pipeline_yaml = ENV['SPEC_NAMES'].split(',').map { |name| "#{name}_spec.rb" }

  difference_between_lists = specs_on_filesystem - specs_in_pipeline_yaml

  if difference_between_lists.empty?
    puts 'All expected integration specs will run'
    exit 0
  else
    puts 'There were integration specs in binary-builder/spec/integration that'
    puts 'were not found in the list of specs to run (integration_spec_names)'
    puts 'in the binary-builder.yml pipeline. You need to add those names to'
    puts 'the pipeline before this task will pass'
    puts
    puts 'The missing specs are:'
    puts '    ' + difference_between_lists.join(", ")

    exit 1
  end
end

