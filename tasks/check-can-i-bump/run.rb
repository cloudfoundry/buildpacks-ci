#!/usr/bin/env ruby
# encoding: utf-8

require 'open-uri'
require 'json'

response = open('https://canibump.cfapps.io/', 'Accept' => 'application/json').read
if JSON.parse(response)['can_i_bump']
  exit 0
else
  puts "\n\n'Can I bump' cf-release status is: No (Red)\nAborting the job..."
  exit 1
end
