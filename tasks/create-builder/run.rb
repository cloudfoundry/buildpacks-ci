#!/usr/bin/env ruby

require 'tomlrb' # One gem to read (supports v0.4.0)
require 'toml' # One to write
require 'json'
require 'net/http'

version             = File.read(File.join("version", "version")).strip()
repo                = ENV.fetch("REPO")
build_image         = ENV.fetch("BUILD_IMAGE")
run_image           = ENV.fetch("RUN_IMAGE")
cnb_stack           = ENV.fetch("STACK")
host                = ENV.fetch("HOST")
enterprise          = ENV.fetch("ENTERPRISE") == 'true'
stack               = cnb_stack.split('.').last
tag                 = "#{version}-#{stack}"
builder_config_file = File.absolute_path("builder.toml")
pack_path           = File.absolute_path('pack-cli')
packager_path       = File.absolute_path('packager-cli')
ci_path             = File.absolute_path('buildpacks-ci')
lifecycle_version   = File.read(File.join("lifecycle", "version")).strip()

if !enterprise # not in a public repo
  json_resp = JSON.load(Net::HTTP.get(URI("https://#{host}/v2/repositories/#{repo}/tags/?page_size=100")))
  if json_resp['results'].any? { |r| r['name'] == tag }
    puts "Image already exists with immutable tag: #{tag}"
    exit 1
  end
end

puts 'Building pack...'
Dir.chdir 'pack' do
  system 'go', 'build', '-mod=vendor', '-o', pack_path, 'cmd/pack/main.go' or exit 1
end

puts 'Building cnb packager...'
Dir.chdir 'packager' do
  system 'go', 'build', '-o', packager_path, 'packager/main.go' or exit 1
end

buildpacks = Dir.glob('sources/*/').map do |dir|
  buildpack_toml_file = 'buildpack.toml'
  id          = Tomlrb.load_file(File.join(dir, buildpack_toml_file))['buildpack']['id']
  bp_location = File.absolute_path(File.join(dir,id))
  local_packager = './packager-cli'
  args = [local_packager, '-uncached']
  args.pop if enterprise
  Dir.chdir dir do
    if File.file?("./scripts/package.sh")
      system File.join(ci_path, 'tasks', 'create-builder', 'set-version.sh') or exit 1
    end

    system 'cp', packager_path, local_packager or exit 1 # We have to do this b/c cnb packager uses arg[0] to find the buildpack.toml
    system *args, bp_location or exit 1
  end
  {
    "id" => id,
    "uri" => bp_location,
    "latest" => true,
  }
end

puts "Loading #{stack}-order.toml"
static_builder_file = Tomlrb.load_file(File.join("cnb-builder", "#{stack}-order.toml"))
groups = static_builder_file['groups']
description = static_builder_file['description']

config_hash = {
  "description" => description,
  "buildpacks" => buildpacks,
  "groups" => groups,
  "stack" => {
    "id" => cnb_stack,
    "build-image" => build_image,
    "run-image" => run_image
  },
  "lifecycle" => {
    "version" => lifecycle_version
  }
}

builder_config = TOML::Generator.new(config_hash).body
File.write(builder_config_file, builder_config)

puts "**************builder.toml**************"
puts builder_config

puts "Starting docker daemon"
system 'buildpacks-ci/scripts/start-docker' or exit 1

repository_host = "localhost"
repository_port = "5000"

puts "Starting local docker registry"
system 'docker', 'run', '-d', '-p', "#{repository_port}:#{repository_port}", '--restart=always', '--name', 'local_registry', 'registry:2' or exit 1

puts "Creating the builder and publishing it to a local registry"
system pack_path, 'create-builder', "#{repository_host}:#{repository_port}/#{repo}:#{stack}", '--builder-config', "#{builder_config_file}", '--publish' or exit 1

puts "Pulling images from local registry"
system 'docker', 'pull', "#{repository_host}:#{repository_port}/#{repo}:#{stack}" or exit 1

puts "Renaming the docker image"
system 'docker', 'tag', "#{repository_host}:#{repository_port}/#{repo}:#{stack}", "#{repo}:#{stack}" or exit 1

puts "Saving the docker image to a local file"
system 'docker', 'save', "#{repo}:#{stack}", '-o', 'builder-image/builder.tgz' or exit 1

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
