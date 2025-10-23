#!/usr/bin/env ruby
require 'English'
require 'json'
require 'yaml'
require 'tmpdir'
require 'date'

require_relative 'dependencies'
require_relative 'php_manifest'
buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

def is_null(value)
  value.nil? || value.empty? || value.downcase == 'null'
end

config = YAML.load_file(File.join(buildpacks_ci_dir, 'pipelines/config/dependency-builds.yml'), permitted_classes: [Date, Time])

BUILD_STACKS = config['build_stacks']
WINDOWS_STACKS = config['windows_stacks']

all_stacks = BUILD_STACKS + WINDOWS_STACKS + ['any-stack']
cflinuxfs4_dependencies = config['cflinuxfs4_dependencies']
cflinuxfs4_buildpacks = config['cflinuxfs4_buildpacks']

manifest = YAML.load_file('buildpack/manifest.yml', permitted_classes: [Date, Time])
manifest_latest_released = YAML.load_file('buildpack-latest-released/manifest.yml', permitted_classes: [Date, Time]) # rescue { 'dependencies' => [] }

data = JSON.parse(File.read('source/data.json'))
source_name = data.dig('source', 'name')
resource_version = data.dig('version', 'ref')
manifest_name = source_name == 'nginx-static' ? 'nginx' : source_name
buildpack_name = manifest['language'].downcase

removal_strategy = ENV.fetch('REMOVAL_STRATEGY', nil)
version_line = ENV.fetch('VERSION_LINE', nil)
version_line_type = ENV.fetch('VERSION_LINE_TYPE', nil)
deprecation_date = ENV.fetch('DEPRECATION_DATE', nil)
deprecation_link = ENV.fetch('DEPRECATION_LINK', nil)
deprecation_match = ENV.fetch('DEPRECATION_MATCH', nil)

system('rsync -a buildpack/ artifacts/')
raise 'Could not copy buildpack to artifacts' unless $CHILD_STATUS.success?

added = []
removed = []
rebuilt = []

total_stacks = []
builds = {}

version = ''

Dir["builds/binary-builds-new/#{source_name}/#{resource_version}-*.json"].each do |stack_dependency_build|
  # See github.com/cloudfoundry/buildpacks-ci/pull/300 - we don't want to process the *cflinuxfs3.json files (they are replaced by *cflinuxfs3-dev.json files)
  next if source_name == 'php' && stack_dependency_build.include?('cflinuxfs3.json')

  if !is_null(deprecation_date) && !is_null(deprecation_link) && version_line != 'latest'
    dependency_deprecation_date = {
      'version_line' => version_line.downcase,
      'name' => manifest_name,
      'date' => Date.parse(deprecation_date),
      'link' => deprecation_link
    }

    dependency_deprecation_date['match'] = deprecation_match unless is_null(deprecation_match)

    deprecation_dates = manifest.fetch('dependency_deprecation_dates', [])
    deprecation_dates = deprecation_dates
                        .reject { |d| d['version_line'] == version_line.downcase and d['name'] == manifest_name }
                        .push(dependency_deprecation_date)
                        .sort_by { |d| [d['name'], d['version_line']] }
    manifest['dependency_deprecation_dates'] = deprecation_dates
  end

  stack = /#{resource_version}-(.*)\.json$/.match(stack_dependency_build)[1]

  # See github.com/cloudfoundry/buildpacks-ci/pull/300 - the build process may create temp stacks like cflinuxfs3-dev
  stack = stack.chomp('-dev') if stack.end_with?('-dev')
  next unless all_stacks.include?(stack) # make sure we not pulling something that's not a stack eg 'preview

  ## TODO: This should be removed when all the buildpacks are built using cflinuxfs4. Right now it only uses the buildpacks included in buildpacks-ci/pipelines/config/dependency-builds.yml --> cflinuxfs4_buildpacks:
  next if !cflinuxfs4_buildpacks.include?(buildpack_name) && stack == 'cflinuxfs4'

  stacks = stack == 'any-stack' ? BUILD_STACKS : [stack]

  # TODO: This should be removed when all the dependencies are built using cflinuxfs4. Right now it only uses the dependencies included in buildpacks-ci/pipelines/config/dependency-builds.yml --> cflinuxfs4_dependencies:
  # TODO: This also includes logic to skip certain version lines based on the skip_lines_cflinuxfs4 array in the config file.
  skip_lines_cflinuxfs4 = config['dependencies'][source_name]&.key?('skip_lines_cflinuxfs4') ? config['dependencies'][source_name]['skip_lines_cflinuxfs4'].map(&:downcase) : []
  stacks -= ['cflinuxfs4'] if !cflinuxfs4_dependencies.include?(source_name) || skip_lines_cflinuxfs4.include?(version_line.downcase)

  # Logic to skip certain version lines that are not supported in cflinuxfs3
  skip_lines_cflinuxfs3 = config['dependencies'][source_name]&.key?('skip_lines_cflinuxfs3') ? config['dependencies'][source_name]['skip_lines_cflinuxfs3'].map(&:downcase) : []
  stacks -= ['cflinuxfs3'] if skip_lines_cflinuxfs3.include?(version_line.downcase)

  stacks = WINDOWS_STACKS if source_name == 'hwc'
  total_stacks |= stacks

  build = JSON.parse(File.read(stack_dependency_build))
  builds[stack] = build

  version = builds[stack]['version'] # We assume that the version is the same for all stacks
  next unless version

  source_type = 'source'
  source_url = builds[stack]['source']['url']
  source_sha256 = builds[stack]['source'].fetch('sha256', '')

  if source_name == 'appdynamics'
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
                 .map { |d| d['version'] }

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

rebuilt = rebuilt.all?
puts 'REBUILD: skipping most version updating logic' if rebuilt

if added.empty? && !rebuilt
  puts 'SKIP: Built version is not required by buildpack.'
  exit 0
end

commit_message = "Add #{manifest_name} #{resource_version}"
commit_message = "Rebuild #{manifest_name} #{resource_version}" if rebuilt
commit_message = "#{commit_message}, remove #{manifest_name} #{removed.join(', ')}" if removed.length.positive?
commit_message += "\n\nfor stack(s) #{total_stacks.join(', ')}"

#
# Special Nginx stuff (for Nginx buildpack)
# * There are two version lines, stable & mainline
#   when we add a new minor line, we should update the version line regex
if !rebuilt && manifest_name == 'nginx' && buildpack_name == 'nginx'
  v = Gem::Version.new(resource_version)
  raise "When setting nginx's version_line, expected to find data['source']['version_filter'], but did not" unless data.dig('source', 'version_filter')

  if v.segments[1].even? # 1.12.X is stable
    manifest['version_lines']['stable'] = data['source']['version_filter'].downcase
  else
    # 1.13.X is mainline
    manifest['version_lines']['mainline'] = data['source']['version_filter'].downcase
  end

end

#
# Special PHP stuff
# Updates default versions for PHP dependencies
# manifest_name will be the name of the dependency, not PHP
manifest['default_versions'] = PHPManifest.update_defaults(manifest, manifest_name, resource_version) if !rebuilt && manifest_name != 'php' && buildpack_name == 'php' && manifest['default_versions']

#
# Special PHP stuff
# * Each php version in the manifest lists the modules and versions it was built with.
#   Get that list for this version of php.
if manifest_name == 'php' && buildpack_name == 'php'
  manifest['dependencies'].each do |dependency|
    next unless dependency.fetch('name') == 'php' && dependency.fetch('version') == resource_version

    sub_deps = builds[total_stacks.last]['sub_dependencies'] || []
    modules = []
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        stack = dependency.fetch('cf_stacks').first
        url = builds[stack]['url']
        `wget --no-verbose #{url} && tar xzf #{File.basename(url)}`

        module_names = Dir['lib/php/extensions/no-debug-non-zts-*/*.so'].collect do |file|
          File.basename(file, '.so')
        end.sort.reject do |m|
          %w[odbc gnupg].include?(m)
        end

        module_names.each do |module_name|
          mod = { 'name' => module_name }
          mod['version'] = sub_deps.fetch(module_name, {})['version'] if sub_deps.fetch(module_name, {})['version'] != '' && sub_deps.fetch(module_name, {})['version'] != 'nil'
          modules << mod
        end
      end
    end
    dependency['dependencies'] = modules
  end
end

#
# Special PHP stuff
# * The appdynamics extension for PHP has a python file with its version number in it.
#   Replace the old version number with the new version we're adding. (if !rebuilt)
path_to_extensions = 'extensions/appdynamics/extension.py'
write_extensions = ''
if !rebuilt && manifest_name == 'appdynamics' && buildpack_name == 'php'
  # TODO: does this change with multiple stacks?
  if removed.length == 1 && added.length == 1
    text = File.read("buildpack/#{path_to_extensions}")
    write_extensions = text.gsub(/#{Regexp.quote(removed.first)}/, added.first)
  else
    puts 'Expected to have one added version and one removed version for appdynamics in the PHP buildpack.'
    puts "Got added (#{added}) and removed (#{removed})."
    exit 1
  end
end

#
# Special JRuby Stuff
# * There are Gemfile(s) in fixtures which depend on the latest JRuby
#   Replace their jruby engine version with the one in the manifest.
ruby_files_to_edit = { 'fixtures/default/sinatra_jruby/Gemfile' => nil }
if !rebuilt && manifest_name == 'jruby' && manifest['language'] == 'ruby'
  version_number = /(9.4.\d+.\d+)/.match(version)
  if version_number
    jruby_version = version_number[0]
    ruby_files_to_edit.each_key do |path|
      text = File.read(File.join('buildpack', path))
      ruby_files_to_edit[path] = text.gsub(/=> '(9.4.\d+.\d+)'/, "=> '#{jruby_version}'")
    end
  end
end

#
# Special R Stuff
# * For the manifest there will be a sub-dependency section for R, as all the dependencies are compiled within
#   for all stacks we have the same sub-dependency(forecast, plumber,...)

if buildpack_name == 'r'
  total_stacks.each do |stack|
    version_messages = (builds[stack]['sub_dependencies'] || []).map do |sub_dep_key, sub_dep_value|
      "#{sub_dep_key} #{sub_dep_value['version']}"
    end.join(', ')

    commit_message += "\nwith dependencies for stack #{stack}: #{version_messages}" unless version_messages == ''

    manifest['dependencies'].map do |dep|
      next unless dep['version'] == version

      dep['dependencies'] = []
      sub_deps = dep['dependencies']
      (builds[stack]['sub_dependencies'] || []).map do |sub_dep_key, sub_dep_value|
        sub_dep = {
          'name' => sub_dep_key,
          'version' => sub_dep_value['version'],
          'source' => sub_dep_value['source']['url'],
          'source_sha256' => sub_dep_value['source']['sha256']
        }
        sub_deps.push(sub_dep)
      end
    end
  end
end

manifest['default_versions'] = [{ 'name' => 'hwc', 'version' => resource_version }] if buildpack_name == 'hwc'

Dir.chdir('artifacts') do
  user_email = ENV['GIT_USER_EMAIL'] || 'app-runtime-interfaces@cloudfoundry.org'
  user_name = ENV['GIT_USER_NAME'] || 'ARI WG Git Bot'

  GitClient.set_global_config('user.email', user_email)
  GitClient.set_global_config('user.name', user_name)

  # Set GPG config
  GitClient.set_gpg_config

  File.write('manifest.yml', manifest.to_yaml)
  GitClient.add_file('manifest.yml')

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

  GitClient.safe_commit(commit_message.to_s)
end
