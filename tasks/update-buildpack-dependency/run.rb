#!/usr/bin/env ruby
require 'json'
require 'yaml'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

manifest = YAML.load_file('buildpack/manifest.yml')
data = JSON.parse(open('source/data.json').read)
name = data.dig('source', 'name')
version = data.dig('version', 'ref')
build = JSON.parse(open("builds/binary-builds-new/#{name}/#{version}.json").read)
story_id = build['tracker_story_id']

system('rsync -a buildpack/ artifacts/')
raise('Could not copy buildpack to artifacts') unless $?.success?

old_version = nil
manifest['dependencies'].each do |dep|
  next unless dep['name'] == name
  raise "Found a second entry for #{name}" if old_version

  old_version = dep['version']
  dep['version'] = build['version']
  dep['uri'] = build['url']
  dep['sha256'] = build['sha256']
end

if Gem::Version.new(build['version']) < Gem::Version.new(old_version)
  puts 'SKIP: Built version is older than current version in buildpack.'
  exit 0
end

Dir.chdir('artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write('manifest.yml', manifest.to_yaml)

  GitClient.add_file('manifest.yml')
  GitClient.safe_commit("Add #{name} #{version}, remove #{name} #{old_version} [##{story_id}]")
end
