#!/usr/bin/env ruby

require 'yaml'

binary_name = ENV['BINARY_NAME']
builds_dir  = File.join(Dir.pwd, 'builds-yaml')
builds_path = File.join(builds_dir, "#{binary_name}-builds.yml")
builds      = YAML.load_file(builds_path)

latest_version = builds[binary_name].shift

unless latest_version
  puts "There are no new builds for #{binary_name} requested."
  exit
end

version        = latest_version['version']
checksum       = latest_version['checksum']

exit system(<<-EOF)
  set -e

  cd binary-builder
  ./bin/binary-builder #{binary_name} #{version} #{checksum}
  BINARY_PATH=$(find -name "*.tgz" -o -name "*.tar.gz")
  md5checksum=$(md5sum $BINARY_PATH | cut --delimiter=" " --fields=1)
  sha256checksum=$(sha256sum $BINARY_PATH | cut --delimiter=" " --fields=1)
  echo "#{builds.to_yaml}" > #{builds_path}
  cd #{builds_dir}
  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"
  git commit -am "Build #{binary_name} - #{version}, md5: $md5checksum, sha256: $sha256checksum"
EOF
