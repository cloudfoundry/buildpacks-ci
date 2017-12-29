#!/usr/bin/env ruby
require 'json'
require 'yaml'
require_relative './dependencies'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

manifest = YAML.load_file('buildpack/manifest.yml')
manifest_master = YAML.load_file('buildpack-master/manifest.yml')

data = JSON.parse(open('source/data.json').read)
name = data.dig('source', 'name')
version = data.dig('version', 'ref')
build = JSON.parse(open("builds/binary-builds-new/#{name}/#{version}.json").read)
story_id = build['tracker_story_id']

system('rsync -a buildpack/ artifacts/')
raise('Could not copy buildpack to artifacts') unless $?.success?

dep = { "name" => name, "version" => version, "uri" => build['url'], "sha256" => build['sha256'], "cf_stacks" => ['cflinuxfs2']}

old_versions = manifest['dependencies'].select { |d| d['name'] == name }.map { |d| d['version'] }
manifest['dependencies'] = Dependencies.new(dep, ENV['VERSION_LINE'], ENV['KEEP_MASTER'], manifest['dependencies'], manifest_master['dependencies']).switch
new_versions = manifest['dependencies'].select { |d| d['name'] == name }.map { |d| d['version'] }

added = (new_versions - old_versions).uniq.sort
removed = (old_versions - new_versions).uniq.sort

if added.length == 0
  puts 'SKIP: Built version is not required by buildpack.'
  exit 0
end

removed_text = ''
if removed.length > 0
  removed_text = ", remove #{name} #{removed.join(', ')}"
end

Dir.chdir('artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write('manifest.yml', manifest.to_yaml)

  GitClient.add_file('manifest.yml')
  GitClient.safe_commit("Add #{name} #{version}#{removed_text} [##{story_id}]")
end
