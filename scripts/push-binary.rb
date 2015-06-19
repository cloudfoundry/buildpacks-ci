#!/usr/bin/env ruby

system('apt-get -y install awscli')

binary_name = ENV['BINARY_NAME']
Dir.glob("build-binary/binary-builder/#{binary_name}-*-linux-x64.{tar.gz,tgz}").each do |file_path|
  file_name = File.basename(file_path)
  if `aws s3 ls s3://pivotal-buildpacks/concourse-binaries/nginx/`.include? file_name
    puts "Binary #{file_name} has already been detected on s3. Skipping upload for this file"
  else
    system("aws s3 cp #{file_path} s3://pivotal-buildpacks/concourse-binaries/#{binary_name}/#{file_name}")
  end
end
