#!/usr/bin/env ruby

require 'tomlrb' # One gem to read them all (supports v0.4.0)
require 'toml' # One to write them
require 'json' # One to bring them all
require 'net/http' # And in the darkness bind them
require 'fileutils'
require 'open3'

def run(*cmd)
    output, err, status = Open3.capture3(*cmd)
    if !status.success?
      STDERR.puts "ERROR: #{err}"
      exit status.exitstatus
    else
      puts output
    end
end

version = File.read(File.join("version", "version")).strip()
repo = ENV.fetch("REPO")
build_image = ENV.fetch("BUILD_IMAGE")
run_image = ENV.fetch("RUN_IMAGE")
cnb_stack = ENV.fetch("STACK")
host = ENV.fetch("HOST")
enterprise = ENV.fetch("ENTERPRISE") == 'true'
stack = cnb_stack.split('.').last
tag = "#{version}-#{stack}"
builder_config_file = File.absolute_path("builder.toml")
pack_path = File.absolute_path('pack-cli')
packager_path = File.absolute_path('packager-cli')
ci_path = File.absolute_path('buildpacks-ci')
lifecycle_version = File.read(File.join("lifecycle", "version")).strip()

if !enterprise # not in a public repo
  json_resp = JSON.load(Net::HTTP.get(URI("https://#{host}/v2/repositories/#{repo}/tags/?page_size=100")))
  if json_resp['results'].any? { |r| r['name'] == tag }
    puts "Image already exists with immutable tag: #{tag}"
    exit 1
  end
end

puts 'Untarring pack'
pack_tar = Dir["pack/*-linux.tgz"].first
FileUtils.mkdir_p pack_path
`tar xvf #{Dir.pwd}/#{pack_tar} -C #{pack_path}`

puts 'Building cnb packager...'
Dir.chdir 'packager' do
  run 'go', 'build', '-o', packager_path, 'packager/main.go'
end

child_buildpacks = []

Dir.glob('sources/*/').each do |dir|
  buildpack_toml_file = 'buildpack.toml'
  buildpack_toml_data = Tomlrb.load_file(File.join(dir, buildpack_toml_file))
  is_metabuildpack = buildpack_toml_data['order']

  if is_metabuildpack
    buildpack_toml_data.dig('metadata','dependencies').each do |dep|
      bp_location = File.absolute_path(File.join(dir, dep['id']))

      res = Net::HTTP.get_response(URI(dep['uri']))
      File.open(bp_location, "wb") do |file|
        file.write res.body
      end
      child_buildpacks.push(
        "id" => dep['id'],
        "uri" => bp_location,
      )
    end
  end
end

individual_buildpacks = Dir.glob('sources/*/').map do |dir|
  buildpack_toml_file = 'buildpack.toml'
  id = Tomlrb.load_file(File.join(dir, buildpack_toml_file)).dig('buildpack','id')
  bp_location = File.absolute_path(File.join(dir, id))
  next if child_buildpacks.map { |buildpack_ids| buildpack_ids['id'] }.include?(id)
  local_packager = './packager-cli'
  args = [local_packager, '-uncached']
  args.pop if enterprise
  Dir.chdir dir do
    if File.file?("./scripts/package.sh")
      run File.join(ci_path, 'tasks', 'create-builder', 'set-version.sh')
    end

    run 'cp', packager_path, local_packager # We have to do this b/c cnb packager uses arg[0] to find the buildpack.toml
    run *args, bp_location
  end
  {
    "id" => id,
    "uri" => bp_location,
  }
end || []
individual_buildpacks.select! { |i| i != nil  }

puts "Loading #{stack}-order.toml"
buildpacks = individual_buildpacks + child_buildpacks
static_builder_file = Tomlrb.load_file(File.join("cnb-builder", "#{stack}-order.toml"))
order = static_builder_file['order']
description = static_builder_file['description']

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

builder_config = TOML::Generator.new(config_hash).body
File.write(builder_config_file, builder_config)

puts "**************builder.toml**************"
puts builder_config

puts "Starting docker daemon"
run 'buildpacks-ci/scripts/start-docker'

repository_host = "localhost"
repository_port = "5000"

puts "Starting local docker registry"
run 'docker', 'run', '-d', '-p', "#{repository_port}:#{repository_port}", '--restart=always', '--name', 'local_registry', 'registry:2'

puts "Creating the builder and publishing it to a local registry"
run "#{pack_path}/pack", 'create-builder', "#{repository_host}:#{repository_port}/#{repo}:#{stack}", '--builder-config', "#{builder_config_file}", '--publish'

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
