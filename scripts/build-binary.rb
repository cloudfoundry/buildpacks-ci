#!/usr/bin/env ruby

require 'yaml'

binary_name = ENV['BINARY_NAME']
builds_dir  = File.join(Dir.pwd, 'builds-yaml')
builds_path = File.join(builds_dir, "#{binary_name}-builds.yml")
builds      = YAML.load_file(builds_path)
version     = builds[binary_name].shift

unless version
  puts "There are no new builds for #{binary_name} requested."
  exit
end

exit system(<<-EOF)
  set -e

  cd binary-builder
  ./bin/binary-builder #{binary_name} #{version}
  BINARY_PATH=$(find -name "*.tgz" -o -name "*.tar.gz")
  CHECKSUM=$(md5sum $BINARY_PATH | cut --delimiter=" " --fields=1)
  echo "#{builds.to_yaml}" > #{builds_path}
  cd #{builds_dir}
  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"
  git commit -am "Build #{binary_name} - #{version}, md5: $CHECKSUM"
EOF
