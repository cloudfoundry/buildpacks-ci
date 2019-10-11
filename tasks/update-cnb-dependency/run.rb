#!/usr/bin/env ruby
require 'json'
require 'toml'
require 'tomlrb'
require 'tmpdir'
require 'date'
require 'set'
require 'yaml'
require_relative './dependency'
require_relative './cnb_dependencies'
require_relative './cnb_dependency_updates'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"
config = YAML.load_file(File.join(buildpacks_ci_dir, 'pipelines/config/dependency-builds.yml'))

CNB_STACKS = config['v3_stacks']
DEPRECATED_STACKS = config['deprecated_stacks']

buildpack_toml_file = 'buildpack.toml'
buildpack_toml = Tomlrb.load_file("buildpack/#{buildpack_toml_file}")
buildpack_toml_latest_released = Tomlrb.load_file('buildpack-latest-released/buildpack.toml')

if buildpack_toml['metadata'] == nil
  buildpack_toml['metadata'] = {}
end

data = JSON.parse(open('source/data.json').read)
dependency_name = data.dig('source', 'name')
resource_version = data.dig('version', 'ref')
story_id = JSON.parse(open("builds/binary-builds-new/#{dependency_name}/#{resource_version}.json").read)['tracker_story_id']
removal_strategy  = ENV['REMOVAL_STRATEGY']
version_line_type = ENV['VERSION_LINE_TYPE']
version_line      = ENV['VERSION_LINE']
deprecation_date  = ENV['DEPRECATION_DATE']
deprecation_link  = ENV['DEPRECATION_LINK']
deprecation_match = ENV['DEPRECATION_MATCH']

system('rsync -a buildpack/ artifacts/')
raise 'Could not copy buildpack to artifacts' unless $?.success?

added = []
removed = []
rebuilt = []
total_stacks = []

# Refactoring Thoughts:
# Maybe have 3 main classes used: Dependency (for cnb dependency), BuildpackToml (for wrapping all buildpack toml stuff)
# And CNBDependencyUpdater (to take in the current bpToml, releasedBPToml, removalStrategy), and have an update-dependency method
# which takes in a dependency, and wraps all the required logic
# The CNBDependency updator or bpToml can keep track of all stacks used, for the commit message stuff
#
# 1. Make CNBDependencies without dep object (so you can have one), and pass the dep into the switch method, so you can pull it out of the loop
# 2. Add method to CNBDependencyUpdates to to wrap within the loop
# 3. Make class to wrap buildpack.toml accessors and getters, and move cnb_dependencies functionality into it(?)
# 4. Ideally restrict config reads to as few files as possible, and enable dependency injection/inversion wherever possible
# 5. Test everything rigorously

no_deprecation_info = (deprecation_date == 'null' or deprecation_link == 'null')
unless no_deprecation_info or (version_line == 'latest')
  deprecation_dates = buildpack_toml['metadata'].fetch('dependency_deprecation_dates', [])
  buildpack_toml['metadata']['dependency_deprecation_dates'] =
      CNBDependencyUpdates.update_dependency_deprecation_dates(deprecation_date, deprecation_link, version_line,
                                                               dependency_name, deprecation_match, deprecation_dates)
end

dependency_build_glob = "builds/binary-builds-new/#{dependency_name}/#{resource_version}-*.json"
Dir[dependency_build_glob].each do |stack_dependency_build|
  stack = /#{resource_version}-(.*)\.json$/.match(stack_dependency_build)[1]
  next if DEPRECATED_STACKS.include?(stack)
  next unless (CNB_STACKS.keys.include? stack) or stack == 'any-stack'

  build = JSON.parse(open(stack_dependency_build).read)
  version = build['version']
  source_url = build.dig('source','url')
  source_sha256 = build.dig('source','sha256')

  v3_stacks, total_stacks = CNBDependencyUpdates.update_stacks_list(stack, dependency_name, total_stacks, CNB_STACKS)
  dep = Dependency.new(dependency_name, resource_version, build['url'], build['sha256'], v3_stacks, source_url, source_sha256)
  old_deps = buildpack_toml['metadata'].fetch('dependencies', [])
  old_versions = old_deps
                     .select {|d| d['id'] == dep.id}
                     .map {|d| d['version']}


  buildpack_toml['metadata']['dependencies'] = CNBDependencies.new(
      dep,
      version_line_type,
      removal_strategy,
      old_deps,
      buildpack_toml_latest_released.fetch('metadata', {}).fetch('dependencies', [])
  ).switch

  new_versions = buildpack_toml['metadata']['dependencies']
                     .select {|d| d['id'] == dep.id}
                     .map {|d| d['version']}

  if CNBDependencyUpdates.update_default_deps?(buildpack_toml, removal_strategy)
    default_deps = buildpack_toml.dig('metadata', 'default_versions')
    default_deps[dependency_name] = version
  end

  added += (new_versions - old_versions).uniq.sort
  removed += (old_versions - new_versions).uniq.sort
  rebuilt += [old_versions.include?(resource_version)]
end

puts "updating buildpack.toml order contents, if they exist, with correct versions"
buildpack_toml.dig('order')&.each do |order_group|
  order_group.dig('group')&.each do |order_elem|
    if order_elem.dig('id') == dependency_name
       order_elem['version'] = resource_version
    end
  end
end

rebuilt = rebuilt.all?()
puts 'REBUILD' if rebuilt

if added.empty? && !rebuilt
  puts 'SKIP: Built version is not required by buildpack.'
  exit 0
end

commit_message = CNBDependencyUpdates.commit_message(dependency_name, resource_version, rebuilt, removed, total_stacks)
buildpack_toml = CNBDependencyUpdates.replace_date_with_time(buildpack_toml)

Dir.chdir('artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write(buildpack_toml_file, TOML::Generator.new(buildpack_toml).body)
  GitClient.add_file(buildpack_toml_file)

  GitClient.safe_commit("#{commit_message} [##{story_id}]")
end
