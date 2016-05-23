#!/usr/bin/env ruby
# encoding: utf-8

binary_name = ENV['BINARY_NAME']
file_path   = Dir.glob("binary-builder-artifacts/#{binary_name}-*.{tar.gz,tgz,phar}").first
unless file_path
  puts 'No binaries detected for upload.'
  exit
end

`apt-get update && apt-get -y install awscli`
file_name = File.basename(file_path)

if binary_name == "composer" then
  version = file_name.gsub("composer-","").gsub(".phar","")
  aws_url =  "s3://pivotal-buildpacks/php/binaries/trusty/composer/#{version}}"
  file_name = "composer.phar"
else
  aws_url =  "s3://pivotal-buildpacks/concourse-binaries/#{binary_name}"
end


if `aws s3 ls #{aws_url}/`.include? file_name
  puts "Binary #{file_name} has already been detected on s3. Skipping upload for this file."
else
  system("aws s3 cp #{file_path} #{aws_url}/#{file_name}")
end
