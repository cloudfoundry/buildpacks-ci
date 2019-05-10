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

if !enterprise # not in a public repo
  json_resp = JSON.load(Net::HTTP.get(URI("#{host}/v2/repositories/#{repo}/tags/?page_size=100")))
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
  id          = Tomlrb.load_file(File.join(dir, "buildpack.toml"))['buildpack']['id']
  bp_location = File.absolute_path(File.join(dir,id))
  local_packager = './packager-cli'
  args = [local_packager, '-uncached']
  args.pop if enterprise
  Dir.chdir dir do
    system 'cp', packager_path, local_packager or exit 1 # We have to do this b/c cnb packager uses arg[0] to find the buildpack.toml
    system *args, bp_location or exit 1
  end
  {
    "id":     id,
    "uri":    bp_location,
    "latest": true,
  }
end

groups = Tomlrb.load_file(File.join("order", "#{stack}-order.toml"))['groups']

config_hash = {
  "buildpacks": buildpacks,
  "groups":     groups,
  "stack":      {
    "id":          cnb_stack,
    "build-image": build_image,
    "run-image":   run_image
  }
}

builder_config = TOML::Generator.new(config_hash).body
File.write(builder_config_file, builder_config)

puts "**************builder.toml**************"
puts builder_config

system 'buildpacks-ci/scripts/start-docker' or exit 1
system pack_path, 'create-builder', "#{repo}:#{stack}", '--builder-config', "#{builder_config_file}" or exit 1
system 'docker', 'save', "#{repo}:#{stack}", '-o', 'builder-image/builder.tgz' or exit 1

File.write(File.join("tag", "name"), tag)

if ENV.fetch('FINAL') == "true"
  File.write(File.join("release-tag", "name"), stack)
end
