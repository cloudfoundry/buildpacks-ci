#!/usr/bin/env ruby
require 'json'
require 'toml'
require 'tmpdir'
require_relative './dependencies'

ALL_STACKS = {
  'cflinuxfs2' => 'org.cloudfoundry.stacks.cflinuxfs2',
  'cflinuxfs3' => 'org.cloudfoundry.stacks.cflinuxfs3',
  'bionic' => 'io.buildpacks.stacks.bionic'
}

V3_DEP_NAMES = {
  'node' => 'NodeJS'
}

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

buildpack_toml = TOML.load_file('buildpack/buildpack.toml')
buildpack_toml_latest_released = begin
                          TOML.load_file('buildpack-latest-released/buildpack.toml')
                        rescue
                          { 'metadata' => {'dependencies' => []} }
                        end

data = JSON.parse(open('source/data.json').read)
manifest_name = data.dig('source', 'name')
resource_version = data.dig('version', 'ref')
story_id = JSON.parse(open("builds/binary-builds-new/#{manifest_name}/#{resource_version}.json").read)['tracker_story_id']
removal_strategy = ENV['REMOVAL_STRATEGY']

system('rsync -a buildpack/ artifacts/')
raise 'Could not copy buildpack to artifacts' unless $?.success?

added = []
removed = []
rebuilt = []
total_stacks = []
builds = {}

Dir["builds/binary-builds-new/#{manifest_name}/#{resource_version}-*.json"].each do |stack_dependency_build|
  stack = /#{resource_version}-(.*)\.json$/.match(stack_dependency_build)[1]
  next unless ALL_STACKS.keys.include? stack

  total_stacks.push ALL_STACKS[stack]

  build = JSON.parse(open(stack_dependency_build).read)
  builds[stack] = build

  dep = {
    'id' => manifest_name,
    'name' => V3_DEP_NAMES[manifest_name],
    'version' => resource_version,
    'uri' => build['url'],
    'sha256' => build['sha256'],
    'stacks' => [ALL_STACKS[stack]]
  }

  old_versions = buildpack_toml['metadata']['dependencies']
                 .select { |d| d['id'] == manifest_name }
                 .map {|d| d['version']}

  buildpack_toml['metadata']['dependencies'] = Dependencies.new(
      dep,
      ENV['VERSION_LINE'],
      removal_strategy,
      buildpack_toml['metadata']['dependencies'],
      buildpack_toml_latest_released['metadata']['dependencies']
  ).switch

  new_versions = buildpack_toml['metadata']['dependencies']
                 .select { |d| d['id'] == manifest_name }
                 .map { |d| d['version'] }

  added += (new_versions - old_versions).uniq.sort
  removed += (old_versions - new_versions).uniq.sort
  rebuilt += [old_versions.include?(resource_version)]
end

rebuilt = rebuilt.all?()
puts 'REBUILD: skipping most version updating logic' if rebuilt

if added.empty? && !rebuilt
  puts 'SKIP: Built version is not required by buildpack.'
  exit 0
end

commit_message = "Add #{manifest_name} #{resource_version}"
commit_message = "Rebuild #{manifest_name} #{resource_version}" if rebuilt
if removed.length > 0
  commit_message = "#{commit_message}, remove #{manifest_name} #{removed.join(', ')}"
end
commit_message = commit_message + "\n\nfor stack(s) #{total_stacks.join(', ')}"

Dir.chdir('artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write('buildpack.toml', TOML::Generator.new(buildpack_toml).body)
  GitClient.add_file('buildpack.toml')

  GitClient.safe_commit("#{commit_message} [##{story_id}]")
end
