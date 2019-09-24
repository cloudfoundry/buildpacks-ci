require 'csv'
require 'json'
require 'pry'

output = JSON.parse(File.read('output.json'))

CSV.open('buildpacks-scan-roots.csv', 'wb') do |csv|
  csv << ['type','repo','commit']
  output.each do |release|
    csv << ['repo',release['repo'],release['commit']]
    csv << ['url-list',release['release']+'-url-list',release['commit']]
  end
end

puts "Done"
