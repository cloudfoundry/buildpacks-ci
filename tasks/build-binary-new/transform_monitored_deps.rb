#!/usr/bin/env ruby
require 'fileutils'
require 'json'
require 'yaml'

DEP_COUNT = ENV.fetch('DEP_COUNT', '0').to_i
OUTPUT_JSON = []

DEP_COUNT.times do |dep_index|
  data = JSON.parse(open("monitored-dep-#{dep_index}/data.json").read)
  name = data.dig('source', 'name')
  version = data.dig('version', 'ref')
  OUTPUT_JSON << { name: name, version: version }
end

File.write('all-monitored-deps/data.json', OUTPUT_JSON.to_json)

