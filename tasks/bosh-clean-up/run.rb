#!/usr/bin/env ruby

require 'yaml'

Dir.chdir("bbl-state/#{ENV['ENV_NAME']}") do
  raise "Failed to bbl print-env" unless system 'eval "$(bbl print-env)"'
end

exit 1 unless system 'bosh clean-up --all'
