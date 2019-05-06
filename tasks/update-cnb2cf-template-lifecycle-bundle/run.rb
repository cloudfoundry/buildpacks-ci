#!/usr/bin/env ruby
require 'json'
require 'yaml'
require_relative '../update-buildpack-dependency/dependencies'
buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

ALL_STACKS = ['cflinuxfs2', 'cflinuxfs3']

repo = 'cnb2cf'
name = 'lifecycle'
manifest_path = "#{repo}/template/manifest.yml"
manifest = YAML.load_file(manifest_path)
version = File.read('s3/version').strip()
build = JSON.parse(File.read("builds/binary-builds-new/lifecycle/#{version}-any-stack.json"))


added = []
removed = []
rebuilt = []

total_stacks = []

source_url = build['source']['url']
source_sha256 = build['source']['sha256']

dep = {
  'name' => name,
  'version' => version,
  'uri' => build['url'],
  'sha256' => build['sha256'],
  'cf_stacks' => ALL_STACKS,
  'source' => source_url,
  'source_sha256' => source_sha256
}

old_versions = manifest.fetch('dependencies', [])
               .select { |d| d['name'] == name }
               .map {|d| d['version']}

manifest['dependencies'] = Dependencies.new(
    dep,
    'major',
    'remove_all',
    manifest['dependencies'],
    []
).switch

new_versions = manifest.fetch('dependencies', [])
               .select { |d| d['name'] == name }
               .map { |d| d['version'] }

added += (new_versions - old_versions).uniq.sort
removed += (old_versions - new_versions).uniq.sort
rebuilt += [old_versions.include?(version)]

rebuilt = rebuilt.all?()
if rebuilt
  puts 'REBUILD: skipping most version updating logic'
end

if added.empty? && !rebuilt
  puts 'SKIP: Built version is not required by buildpack.'
  exit 0
end

commit_message = "Add #{name} #{version}"
if rebuilt
  commit_message = "Rebuild #{name} #{version}"
end
if removed.length > 0
  commit_message = "#{commit_message}, remove #{name} #{removed.join(', ')}"
end
commit_message = commit_message + "\n\nfor stack(s) #{total_stacks.join(', ')}"

Dir.chdir(repo) do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write(manifest_path, manifest.to_yaml)
  GitClient.add_file(manifest_path)

  GitClient.safe_commit(commit_message)
end
