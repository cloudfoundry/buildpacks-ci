#!/usr/bin/env ruby

binary_name = ENV['BINARY_NAME']
file_path   = Dir.glob("build-binary/binary-builder/#{binary_name}-*.{tar.gz,tgz}").first
unless file_path
  puts "No binaries detected for upload."
  exit
end

`apt-get -y install awscli`
file_name = File.basename(file_path)
if `aws s3 ls s3://pivotal-buildpacks/concourse-binaries/#{binary_name}/`.include? file_name
  puts "Binary #{file_name} has already been detected on s3. Skipping upload for this file."
else
  system("aws s3 cp #{file_path} s3://pivotal-buildpacks/concourse-binaries/#{binary_name}/#{file_name}")
end
