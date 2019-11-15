#!/usr/bin/env ruby

require_relative '../lib/buildpacks-ci-configuration'
require 'yaml'

# USAGE: just pass any prefix string of the pipeline you want eg ./bin/preview-pipeline dependency-buil
# will output the dependency-builds pipeline

def preview_pipelines(args)
  buildpacks_configuration = BuildpacksCIConfiguration.new
  organization = buildpacks_configuration.organization
  run_php_oracle_tests = buildpacks_configuration.run_oracle_php_tests?

  selector = ""
  if args.size > 0
    selector = args[0]
  end

  if args.size > 1
    outstring = `erb language=#{selector} organization=#{organization} pipelines/templates/metabuildpack-cnb.yml.erb`
    puts outstring.gsub(/\nS+/, "\n")
  else
    Dir['pipelines/*.{erb,yml}'].each do |filename|
      if File.basename(filename).start_with?(selector)
        outstring = `erb organization=#{organization} run_oracle_php_tests=#{run_php_oracle_tests} #{filename}`
        puts outstring.gsub(/\nS+/, "\n")
      end
    end
  end
end

preview_pipelines(ARGV)
