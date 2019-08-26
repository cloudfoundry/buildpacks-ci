#!/usr/bin/env ruby
require 'json'
require 'toml'
require 'tmpdir'
require 'date'
require_relative './dependencies'

CNB_STACKS = {
  'cflinuxfs3' => 'org.cloudfoundry.stacks.cflinuxfs3',
  'bionic'     => 'io.buildpacks.stacks.bionic'
}

V3_DEP_IDS = {
  'php' => 'php-binary',
  'dotnet-aspnetcore' => 'dotnet-aspnet'
}

V3_DEP_NAMES = {
  'node' => 'Node Engine',
  'yarn' => 'Yarn',
  'python' => 'Python',
  'php' => 'PHP',
  'httpd' => 'Apache HTTP Server',
  'go' => 'Go',
  'dep' => 'Dep',
  'nginx' => 'Nginx Server',
  'pipenv' => "Pipenv",
  'miniconda3' => "Miniconda",
  'bundler' => "Bundler",
  'ruby' => "Ruby"
}

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

buildpack_toml_file = 'buildpack.toml'
buildpack_toml = TOML.load_file("buildpack/#{buildpack_toml_file}")
buildpack_toml_latest_released = TOML.load_file('buildpack-latest-released/buildpack.toml')

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
builds = {}

dependency_build_glob = "builds/binary-builds-new/#{dependency_name}/#{resource_version}-*.json"
Dir[dependency_build_glob].each do |stack_dependency_build|
  no_deprecation_info = (deprecation_date.nil? or deprecation_link.nil?)
  unless no_deprecation_info or (version_line == 'latest')
    dependency_deprecation_date = {
      'version_line' => version_line.downcase,
      'name'         => dependency_name,
      'date'         => DateTime.parse(deprecation_date),
      'link'         => deprecation_link,
    }

    unless deprecation_match.nil? or deprecation_match.empty? or deprecation_match.downcase == 'null'
      dependency_deprecation_date['match'] = deprecation_match
    end

    deprecation_dates = buildpack_toml['metadata'].fetch('dependency_deprecation_dates', [])
    deprecation_dates = deprecation_dates
                          .reject{ |d| d['version_line'] == version_line.downcase and d['name'] == dependency_name}
                          .push(dependency_deprecation_date)
                          .sort_by{ |d| [d['name'], d['version_line'] ]}
    buildpack_toml['metadata']['dependency_deprecation_dates'] = deprecation_dates
  end

  stack = /#{resource_version}-(.*)\.json$/.match(stack_dependency_build)[1]

  if stack == 'cflinuxfs2'
    next
  end

  if stack == 'any-stack'
    total_stacks.concat CNB_STACKS.values
    v3_stacks = CNB_STACKS.values
  elsif stack == 'cflinuxfs3' and dependency_name == 'dep' # NOTE: This case is temporary. For now, we will use cflinuxfs3 dependencies for bionic as well.
    total_stacks.concat CNB_STACKS.values
    v3_stacks = CNB_STACKS.values
  else
    next unless CNB_STACKS.keys.include? stack
    total_stacks.push CNB_STACKS[stack]
    v3_stacks = [CNB_STACKS[stack]]
  end

  build = JSON.parse(open(stack_dependency_build).read)
  builds[stack] = build

  version = builds[stack]['version'] # We assume that the version is the same for all stacks
  source_type = 'source'
  source_url = ''
  source_sha256 = ''

  if stack != "bionic"
    begin
      source_url = builds[stack]['source']['url']
      source_sha256 = builds[stack]['source'].fetch('sha256', '')
    rescue
      next
    end
  end

  if dependency_name.include? 'dotnet'
    git_commit_sha = builds[stack]['git_commit_sha']
    source_url = "#{source_url}/archive/#{git_commit_sha}.tar.gz"
  elsif dependency_name == 'appdynamics'
    source_type = 'osl'
    source_url = 'https://docs.appdynamics.com/display/DASH/Legal+Notices'
  elsif dependency_name == 'CAAPM'
    source_type = 'osl'
    source_url = 'https://docops.ca.com/ca-apm/10-5/en/ca-apm-release-notes/third-party-software-acknowledgments/php-agents-third-party-software-acknowledgments'
  elsif dependency_name.include? 'miniconda'
    source_url = "https://github.com/conda/conda/archive/#{version}.tar.gz"
  end

  if source_sha256 != ""
    dep = {
      'id' => V3_DEP_IDS.fetch(dependency_name, dependency_name),
      'name' => V3_DEP_NAMES[dependency_name],
      'version' => resource_version,
      'uri' => build['url'],
      'sha256' => build['sha256'],
      'stacks' => v3_stacks,
      source_type => source_url,
      'source_sha256' => source_sha256
    }
  else
    dep = {
        'id' => V3_DEP_IDS.fetch(dependency_name, dependency_name),
        'name' => V3_DEP_NAMES[dependency_name],
        'version' => resource_version,
        'uri' => build['url'],
        'sha256' => build['sha256'],
        'stacks' => v3_stacks,
    }
  end

  old_deps = buildpack_toml['metadata'].fetch('dependencies', [])
  old_versions = old_deps
                     .select {|d| d['id'] == V3_DEP_IDS.fetch(dependency_name, dependency_name)}
                     .map {|d| d['version']}

  buildpack_toml['metadata']['dependencies'] = Dependencies.new(
      dep,
      version_line_type,
      removal_strategy,
      old_deps,
      buildpack_toml_latest_released['metadata'].fetch('dependencies', [])
  ).switch

  new_versions = buildpack_toml['metadata']['dependencies']
                     .select {|d| d['id'] == V3_DEP_IDS.fetch(dependency_name, dependency_name)}
                     .map {|d| d['version']}

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

commit_message = "Add #{dependency_name} #{resource_version}"
commit_message = "Rebuild #{dependency_name} #{resource_version}" if rebuilt
if removed.length > 0
  commit_message = "#{commit_message}, remove #{dependency_name} #{removed.join(', ')}"
end
commit_message = commit_message + "\n\nfor stack(s) #{total_stacks.join(', ')}"

Dir.chdir('artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write(buildpack_toml_file, TOML::Generator.new(buildpack_toml).body)
  GitClient.add_file(buildpack_toml_file)

  GitClient.safe_commit("#{commit_message} [##{story_id}]")
end
