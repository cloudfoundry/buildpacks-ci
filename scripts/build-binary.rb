#!/usr/bin/env ruby

require 'yaml'

binary_name  = ENV['BINARY_NAME']
builds_dir   = File.join(Dir.pwd, 'builds-yaml')
builds_path  = File.join(builds_dir, "#{binary_name}-builds.yml")
builds       = YAML.load_file(builds_path)
latest_build = builds[binary_name].shift

unless latest_build
  puts "There are no new builds for #{binary_name} requested."
  exit
end

if (!binary_name.include? "-test")
  builds_path_test  = File.join(builds_dir, "#{binary_name}-test-builds.yml")
  builds_test       = YAML.load_file(builds_path_test)
  builds_test[binary_name+"-test"].push(latest_build)
  `echo "#{builds_test.to_yaml}" > #{builds_path_test}`
end


flags = "--name=#{binary_name}"
latest_build.each_pair do |key, value|
  flags << %Q{ --#{key}="#{value}"}
end

exit system(<<-EOF)
  set -e

  cd binary-builder
  ./bin/binary-builder #{flags}
  filename=$(ls *.tgz | head -n 1)
  md5checksum=$(md5sum $filename | cut --delimiter=" " --fields=1)
  sha256checksum=$(sha256sum $filename | cut --delimiter=" " --fields=1)
  echo "#{builds.to_yaml}" > #{builds_path}
  cd #{builds_dir}
  git config --global user.email "ci@localhost"
  git config --global user.name "CI Bot"
  git commit -am "Build #{binary_name} - #{latest_build['version']}, filename: $filename, md5: $md5checksum, sha256: $sha256checksum"
EOF
