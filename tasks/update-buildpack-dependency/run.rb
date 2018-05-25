#!/usr/bin/env ruby
require 'json'
require 'yaml'
require_relative './dependencies'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

manifest = YAML.load_file('buildpack/manifest.yml')
manifest_master = YAML.load_file('buildpack-master/manifest.yml') # rescue { 'dependencies' => [] }

data = JSON.parse(open('source/data.json').read)
name = data.dig('source', 'name')
build = JSON.parse(open("builds/binary-builds-new/#{name}/#{version}.json").read)
story_id = build['tracker_story_id']
version = build['version']

system('rsync -a buildpack/ artifacts/')
raise('Could not copy buildpack to artifacts') unless $?.success?

dep = { "name" => name, "version" => version, "uri" => build['url'], "sha256" => build['sha256'], "cf_stacks" => ['cflinuxfs2']}

old_versions = manifest['dependencies'].select { |d| d['name'] == name }.map { |d| d['version'] }
manifest['dependencies'] = Dependencies.new(dep, ENV['VERSION_LINE'], ENV['REMOVAL_STRATEGY'], manifest['dependencies'], manifest_master['dependencies']).switch
new_versions = manifest['dependencies'].select { |d| d['name'] == name }.map { |d| d['version'] }

added = (new_versions - old_versions).uniq.sort
removed = (old_versions - new_versions).uniq.sort
rebuilt = old_versions.include?(version)

if added.length == 0 && !rebuilt
  puts 'SKIP: Built version is not required by buildpack.'
  exit 0
end

path_to_extensions = 'extensions/appdynamics/extension.py'
write_extensions = ''
if !rebuilt && name == 'appdynamics' && manifest['language'] == 'php'
  if removed.length == 1 && added.length == 1
    text = File.read('buildpack/' + path_to_extensions)
    write_extensions = text.gsub(/#{Regexp.quote(removed.first)}/, added.first)
  else
   puts 'Expected to have one added version and one removed version for appdynamics in the PHP buildpack.'
   puts 'Got added (#{added}) and removed (#{removed}).'
   exit 1
  end
end

commit_message = "Add #{name} #{version}"
if rebuilt
  commit_message = "Rebuild #{name} #{version}"
end
if removed.length > 0
  commit_message = "#{commit_message}, remove #{name} #{removed.join(', ')}"
end

Dir.chdir('artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write('manifest.yml', manifest.to_yaml)
  GitClient.add_file('manifest.yml')

  if write_extensions != ''
    File.write(path_to_extensions, write_extensions)
    GitClient.add_file(path_to_extensions)
  end

  GitClient.safe_commit("#{commit_message} [##{story_id}]")
end
