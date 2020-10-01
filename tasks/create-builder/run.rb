#!/usr/bin/env ruby

require 'tomlrb' # One gem to read them all (supports v0.4.0)
require 'toml' # One to write them
require 'json' # One to bring them all
require 'net/http' # And in the darkness bind them
require 'fileutils'
require 'open3'
require 'net/http'
require 'uri'
require 'rubygems/package'
require 'zlib'

def run(*cmd)
    puts *cmd.join(" ")
    output, err, status = Open3.capture3(*cmd)
    if !status.success?
      STDERR.puts "\n\nERROR: #{err}\n\n\n OUTPUT: #{output}\n\n"
      exit status.exitstatus
    else
      puts output
    end
end

def http_fetch(uri_str, output, limit = 10)
  raise ArgumentError, 'Too many HTTP redirects' if limit == 0

  uri = URI.parse(uri_str)
  request = Net::HTTP::Get.new(uri)
  if limit == 10
  request["Authorization"] = "Bearer #{output.strip}"
  end
  req_options = {
    use_ssl: uri.scheme == "https",
  }
  res = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end
  case res
  when Net::HTTPSuccess     then res
  when Net::HTTPRedirection then http_fetch(res['location'], output, limit - 1)
  else
     STDERR.puts "\n\nERROR: HTTP Request failed \n\n\n Response: #{res}\n\n"
  end
end

def set_version_in_order(order, id, version)
  order.each do |o|
    o['group'].each do |buildpack|
      if buildpack['id'] == id
        buildpack['version'] = version
      end
    end
  end
end

version = File.read(File.join("version", "version")).strip()
repo = ENV.fetch("REPO")
build_image = ENV.fetch("BUILD_IMAGE")
run_image = ENV.fetch("RUN_IMAGE")
run_image_mirrors = ENV.fetch("RUN_IMAGE_MIRRORS")
cnb_stack = ENV.fetch("STACK")
enterprise = ENV.fetch("ENTERPRISE") == 'true'
registry_password = ENV.fetch("REGISTRY_PASSWORD")
stack = cnb_stack.split('.').last
stack_name = ENV.fetch("STACK_NAME")
tag = "#{version}-#{stack}"
builder_config_file = File.absolute_path("builder.toml")
pack_path = File.absolute_path('pack-cli')
packager_path = File.absolute_path('packager-cli')
ci_path = File.absolute_path('buildpacks-ci')
lifecycle_version = File.read(File.join("lifecycle", "version")).strip()

if !enterprise # not in a public repo
  json_resp = JSON.load(Net::HTTP.get(URI("https://gcr.io/v2/#{repo}/tags/list?page_size=100")))
  if json_resp['tags']&.any? { |r| r == tag }
    puts "Image already exists with immutable tag: #{tag}"
    exit 1
  end
end

if enterprise
  output, err, status = Open3.capture3("echo '#{registry_password}' | docker login -u _json_key --password-stdin https://gcr.io/tanzu-buildpacks")
  if !status.success?
    STDERR.puts "\n\nERROR: #{err}\n\n\n OUTPUT: #{output}\n\n"
    exit status.exitstatus
  else
    puts output
  end
end

puts 'Untarring pack'
pack_tar = Dir["pack/*-linux.tgz"].first
FileUtils.mkdir_p pack_path
run "tar xvf #{Dir.pwd}/#{pack_tar} -C #{pack_path}"

puts 'Building cnb packager...'
Dir.chdir 'packager' do
  run 'go', 'build', '-o', packager_path, 'packager/main.go'
end


static_builder_file = Tomlrb.load_file(File.join("cnb-builder", "#{stack_name}-order.toml"))
order = static_builder_file['order']
description = static_builder_file['description']

buildpacks = Dir.glob('published-sources/*/').map do |dir|
  image_tar = File.join(dir, 'image.tar')
  run "tar xf #{image_tar} -C #{dir}"

  manifest_json = JSON.parse(File.read(File.join(dir, 'manifest.json')))
  config_file_name = manifest_json[0]['Config']
  config_json = JSON.parse(File.read(File.join(dir, config_file_name)))
  metadata = config_json['config']['Labels']['io.buildpacks.buildpackage.metadata']
  metadata_json = JSON.parse(metadata)

  id = metadata_json['id']
  version = metadata_json['version']

  set_version_in_order(order, id, version)
  {"image" => "gcr.io/#{id}:#{version}", "version" => version}
end || []
buildpacks.select! { |i| i != nil  }

config_hash = {
  "description" => description,
  "buildpacks" => buildpacks,
  "order" => order,
  "stack" => {
    "id" => cnb_stack,
    "build-image" => build_image,
    "run-image" => run_image
  },
  "lifecycle" => {
    "version" => lifecycle_version
  }
}
if !run_image_mirrors.empty?
  config_hash["stack"]["run-image-mirrors"] = run_image_mirrors.split(",")
end

builder_config = TOML::Generator.new(config_hash).body
File.write(builder_config_file, builder_config)

puts "**************builder.toml**************"
puts builder_config

repository_host = "localhost"
repository_port = "5000"

puts "Starting local docker registry"
run 'docker', 'run', '-d', '-p', "#{repository_port}:#{repository_port}", '--restart=always', '--name', 'local_registry', 'registry:2'

puts "Creating the builder and publishing it to a local registry"
run "#{pack_path}/pack", 'create-builder', "#{repository_host}:#{repository_port}/#{repo}:#{stack}", '--config', "#{builder_config_file}", '--publish'

puts "Pulling images from local registry"
run 'docker', 'pull', "#{repository_host}:#{repository_port}/#{repo}:#{stack}"

puts "Renaming the docker image"
run 'docker', 'tag', "#{repository_host}:#{repository_port}/#{repo}:#{stack}", "#{repo}:#{stack}"

puts "Saving the docker image to a local file"
run 'docker', 'save', "#{repo}:#{stack}", '-o', 'builder-image/builder.tgz'

File.write(File.join("tag", "name"), tag)

if ENV.fetch('FINAL') == "true"
  tagFile = stack
  if stack == 'bionic'
    tagFile += " base" # Need a white-space separated list of tags
  elsif stack == 'cflinuxfs3'
    tagFile += " full"
  end
  File.write(File.join("release-tag", "name"), tagFile)
end
