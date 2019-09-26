#!/usr/bin/env ruby
require 'json'
require 'yaml'
require 'tmpdir'
require 'date'
require_relative './dependencies'
require_relative './php_manifest'
config = YAML.load_file(File.join(__dir__, '../../pipelines/config/dependency-builds.yml'))

ALL_STACKS = config['stacks']
WINDOWS_STACKS = config['windows_stacks']

# Stacks we dont want to process (most likely V3 stacks)
IGNORED_STACKS = ['bionic']

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

manifest = YAML.load_file('buildpack/manifest.yml')
manifest_latest_released = YAML.load_file('buildpack-latest-released/manifest.yml') # rescue { 'dependencies' => [] }

data = JSON.parse(open('source/data.json').read)
source_name = data.dig('source', 'name')
resource_version = data.dig('version', 'ref')
manifest_name = source_name == 'nginx-static' ? 'nginx' : source_name

# create story is one-per-version; it creates the json file with the tracker ID
story_id = JSON.parse(open("builds/binary-builds-new/#{source_name}/#{resource_version}.json").read)['tracker_story_id']

removal_strategy   = ENV['REMOVAL_STRATEGY']
version_line       = ENV['VERSION_LINE']
version_line_type  = ENV['VERSION_LINE_TYPE']
deprecation_date   = ENV['DEPRECATION_DATE']
deprecation_link   = ENV['DEPRECATION_LINK']
deprecation_match  = ENV['DEPRECATION_MATCH']

system('rsync -a buildpack/ artifacts/')
raise 'Could not copy buildpack to artifacts' unless $?.success?

added = []
removed = []
rebuilt = []

total_stacks = []
builds = {}

version = ''

Dir["builds/binary-builds-new/#{source_name}/#{resource_version}-*.json"].each do |stack_dependency_build|
  unless deprecation_date == 'null' or deprecation_link == 'null' or version_line == 'latest'
    dependency_deprecation_date = {'version_line' => version_line.downcase, 'name' => manifest_name, 'date' => Date.parse(deprecation_date), 'link' => deprecation_link, }
    dependency_deprecation_date['match'] = deprecation_match unless deprecation_match.nil? or deprecation_match.empty? or deprecation_match.downcase == 'null'

    deprecation_dates = manifest.fetch('dependency_deprecation_dates', [])
    deprecation_dates = deprecation_dates
                          .reject{ |d| d['version_line'] == version_line.downcase and d['name'] == manifest_name}
                          .push(dependency_deprecation_date)
                          .sort_by {|d| [d['name'], d['version_line']]}
    manifest['dependency_deprecation_dates'] = deprecation_dates
  end

  stack = %r{#{resource_version}-(.*)\.json$}.match(stack_dependency_build)[1]
  next if IGNORED_STACKS.include?(stack)

  stacks = (stack == 'any-stack') ? ALL_STACKS : [stack]
  stacks = WINDOWS_STACKS if source_name == 'hwc'
  total_stacks = total_stacks | stacks

  build = JSON.parse(open(stack_dependency_build).read)
  builds[stack] = build

  version = builds[stack]['version'] # We assume that the version is the same for all stacks

  source_type = 'source'
  source_url = builds[stack]['source']['url']
  source_sha256 = builds[stack]['source'].fetch('sha256', '')

  if source_name.include? 'dotnet'
    git_commit_sha = builds[stack]['git_commit_sha']
    source_url = "#{source_url}/archive/#{git_commit_sha}.tar.gz"
  elsif source_name == 'appdynamics'
    source_type = 'osl'
    source_url = 'https://docs.appdynamics.com/display/DASH/Legal+Notices'
  elsif source_name == 'CAAPM'
    source_type = 'osl'
    source_url = 'https://docops.ca.com/ca-apm/10-5/en/ca-apm-release-notes/third-party-software-acknowledgments/php-agents-third-party-software-acknowledgments'
  elsif source_name.include? 'miniconda'
    source_url = "https://github.com/conda/conda/archive/#{version}.tar.gz"
  end

  dep = {
    'name' => manifest_name,
    'version' => resource_version,
    'uri' => build['url'],
    'sha256' => build['sha256'],
    'cf_stacks' => stacks,
    source_type => source_url,
    'source_sha256' => source_sha256
  }

  old_versions = manifest['dependencies']
                 .select { |d| d['name'] == manifest_name }
                 .map {|d| d['version']}

  manifest['dependencies'] = Dependencies.new(
      dep,
      version_line_type,
      removal_strategy,
      manifest['dependencies'],
      manifest_latest_released['dependencies']
  ).switch

  new_versions = manifest['dependencies']
                   .select { |d| d['name'] == manifest_name }
                   .map { |d| d['version'] }

  added += (new_versions - old_versions).uniq.sort
  removed += (old_versions - new_versions).uniq.sort
  rebuilt += [old_versions.include?(resource_version)]
end

rebuilt = rebuilt.all?()
if rebuilt
  puts 'REBUILD: skipping most version updating logic'
end

if added.empty? && !rebuilt
  puts 'SKIP: Built version is not required by buildpack.'
  exit 0
end

commit_message = "Add #{manifest_name} #{resource_version}"
if rebuilt
  commit_message = "Rebuild #{manifest_name} #{resource_version}"
end
if removed.length > 0
  commit_message = "#{commit_message}, remove #{manifest_name} #{removed.join(', ')}"
end
commit_message = commit_message + "\n\nfor stack(s) #{total_stacks.join(', ')}"

#
# Special Nginx stuff (for Nginx buildpack)
# * There are two version lines, stable & mainline
#   when we add a new minor line, we should update the version line regex
if !rebuilt && manifest_name == 'nginx' && manifest['language'] == 'nginx'
  v = Gem::Version.new(resource_version)
  if data.dig('source', 'version_filter')
    if v.segments[1].even? # 1.12.X is stable
      manifest['version_lines']['stable'] = data['source']['version_filter'].downcase
    else # 1.13.X is mainline
      manifest['version_lines']['mainline'] = data['source']['version_filter'].downcase
    end
  else
    raise "When setting nginx's version_line, expected to find data['source']['version_filter'], but did not"
  end
end

#
# Special PHP stuff
# * The defaults/options.json file contains default version numbers to use for each PHP line.
#   Update the default version for the relevant line to this version of PHP (if !rebuilt)
php_defaults = nil
if !rebuilt && manifest_name == 'php' && manifest['language'] == 'php'
  update_default = false
  case resource_version
  when /^7.1/
    varname = 'PHP_71_LATEST'
  when /^7.2/
    varname = 'PHP_72_LATEST'
    update_default = true
  when /^7.3/
    varname = 'PHP_73_LATEST'
  else
    puts "Unexpected version #{resource_version} is not in known version lines."
    exit 1
  end

  php_defaults = JSON.parse(open('buildpack/defaults/options.json').read)
  php_defaults[varname] = resource_version
  if update_default
    php_defaults['PHP_DEFAULT'] = resource_version
    manifest['default_versions'] = PHPManifest.update_defaults(manifest, resource_version)
  end
end

#
# Special PHP stuff
# * Each php version in the manifest lists the modules it was built with.
#   Get that list for this version of php.
if manifest_name == 'php' && manifest['language'] == 'php'
  manifest['dependencies'].each do |dependency|
    if dependency.fetch('name') == 'php' && dependency.fetch('version') == resource_version
      modules = Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          stack = dependency.fetch('cf_stacks').first
          url = builds[stack]['url']
          `wget --no-verbose #{url} && tar xzf #{File.basename(url)}`
          Dir['php/lib/php/extensions/no-debug-non-zts-*/*.so'].collect do |file|
            File.basename(file, '.so')
          end.sort.reject do |m|
            %w[odbc gnupg].include?(m)
          end
        end
      end
      dependency['modules'] = modules
    end
  end
end

#
# Special PHP stuff
# * The appdynamics extension for PHP has a python file with its version number in it.
#   Replace the old version number with the new version we're adding. (if !rebuilt)
path_to_extensions = 'extensions/appdynamics/extension.py'
write_extensions = ''
if !rebuilt && manifest_name == 'appdynamics' && manifest['language'] == 'php'
  # TODO: does this change with multiple stacks?
  if removed.length == 1 && added.length == 1
    text = File.read('buildpack/' + path_to_extensions)
    write_extensions = text.gsub(/#{Regexp.quote(removed.first)}/, added.first)
  else
    puts 'Expected to have one added version and one removed version for appdynamics in the PHP buildpack.'
    puts "Got added (#{added}) and removed (#{removed})."
    exit 1
  end
end

#
# Special JRuby Stuff
# * There are two Gemfiles in fixtures which depend on the latest JRuby in the 9.2.X.X line.
#   Replace their jruby engine version with the one in the manifest.
ruby_files_to_edit = { 'fixtures/sinatra_jruby/Gemfile' => nil, 'fixtures/jruby_start_command/Gemfile' => nil }
if !rebuilt && manifest_name == 'jruby' && manifest['language'] == 'ruby'
  version_number = /(9.2.\d+.\d+)/.match(version)
  if version_number
    jruby_version = version_number[0]
    ruby_files_to_edit.each_key do |path|
      text = File.read(File.join('buildpack', path))
      ruby_files_to_edit[path] = text.gsub(/=> '(9.2.\d+.\d+)'/, "=> '#{jruby_version}'")
    end
  end
end

#
# Special R Stuff
# * For the manifest there will be a sub-dependency section for R, as all the dependencies are compiled within
#   for all stacks we have the same sub-dependency(forecast, plumber,...)

if manifest['language'].downcase == 'r'
  total_stacks.each do |stack|
    version_messages = (builds[stack]['sub_dependencies'] || []).map do |sub_dep_key, sub_dep_value |
      "#{sub_dep_key} #{sub_dep_value['version'].to_s}"
    end.join(", ")

    unless version_messages == ""
      commit_message += "\nwith dependencies for stack #{stack}: #{version_messages}"
    end

    manifest["dependencies"].map do |dep|

      if dep["version"] == version
        dep["dependencies"] = []
        sub_deps = dep["dependencies"]
        (builds[stack]['sub_dependencies'] || []).map do |sub_dep_key, sub_dep_value |
          sub_dep = {
            'version' => sub_dep_value['version'],
            'source' => sub_dep_value['source']['url'],
            'source_sha256' =>  sub_dep_value['source']['sha256']
          }
          sub_deps.push(sub_dep_key => sub_dep)
        end
      end
    end
  end
end


Dir.chdir('artifacts') do
  GitClient.set_global_config('user.email', 'cf-buildpacks-eng@pivotal.io')
  GitClient.set_global_config('user.name', 'CF Buildpacks Team CI Server')

  File.write('manifest.yml', manifest.to_yaml)
  GitClient.add_file('manifest.yml')

  unless php_defaults.nil?
    File.write('defaults/options.json', php_defaults.to_json)
    GitClient.add_file('defaults/options.json')
  end

  ruby_files_to_edit.each do |path, content|
    if content
      File.write(path, content)
      GitClient.add_file(path)
    end
  end

  if write_extensions != ''
    File.write(path_to_extensions, write_extensions)
    GitClient.add_file(path_to_extensions)
  end

  GitClient.safe_commit("#{commit_message} [##{story_id}]")
end
