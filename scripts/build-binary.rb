#!/usr/bin/env ruby

require 'yaml'

binary_name = ENV['BINARY_NAME']
builds_path = File.join(Dir.pwd, 'builds-yaml', "#{binary_name}-builds.yml")
builds = YAML.load_file(builds_path)
versions = builds[binary_name]

if versions.empty?
  puts "There are no new builds for #{binary_name} requested"
  exit
end

versions.delete_if do |version|
  system(<<-EOF)
    cd binary-builder
    ./bin/binary-builder #{binary_name} #{version}
  EOF
end

exit 1 unless versions.empty?

system(<<-EOF)
  echo "#{builds.to_yaml}" > #{builds_path}
  cd ../builds-yaml
  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"
  git commit -am "Completed building #{binary_name} and removing it from builds"
EOF
