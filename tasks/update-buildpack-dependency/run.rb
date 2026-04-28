#!/usr/bin/env ruby
require 'English'
require 'json'
require 'yaml'
require 'tmpdir'
require 'date'
require 'semver'

require_relative 'dependencies'
require_relative 'php_manifest'
buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

def is_null(value)
  value.nil? || value.empty? || value.downcase == 'null'
end

config = YAML.load_file(File.join(buildpacks_ci_dir, 'pipelines/dependency-builds/config.yml'), permitted_classes: [Date, Time])

BUILD_STACKS = config['build_stacks']
WINDOWS_STACKS = config['windows_stacks']

all_stacks = BUILD_STACKS + WINDOWS_STACKS + ['any-stack']

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

any_stack_build_exists = Dir["builds/binary-builds-new/#{source_name}/#{resource_version}-any-stack.json"].any?

Dir["builds/binary-builds-new/#{source_name}/#{resource_version}-*.json"].each do |stack_dependency_build|
  # Skip stack-specific builds when an any-stack build exists - the any-stack build covers all stacks
  # and will replace all existing stack-specific entries in one pass
  next if any_stack_build_exists && !stack_dependency_build.include?('any-stack.json')

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

  stack = /#{Regexp.escape(resource_version)}-(.*)\.json$/.match(stack_dependency_build)[1]
  next unless all_stacks.include?(stack)

  stacks = stack == 'any-stack' ? BUILD_STACKS : [stack]

  skip_lines_per_stack = config.dig('dependencies', source_name, 'skip_lines') || {}
  skip_lines_per_stack.each do |stack_name, lines|
    stacks -= [stack_name] if lines.map(&:downcase).include?(version_line.downcase)
  end

  stacks = WINDOWS_STACKS if source_name == 'hwc'
  total_stacks |= stacks

  build = JSON.parse(File.read(stack_dependency_build))
  builds[stack] = build

  version = builds[stack]['version'] # We assume that the version is the same for all stacks
  next unless version

  source_type = 'source'
  source_url = builds[stack]['source']['url']
  source_sha256 = builds[stack]['source'].fetch('sha256', nil).to_s

  if source_name == 'appdynamics'
    source_type = 'osl'
    source_url = 'https://docs.appdynamics.com/display/DASH/Legal+Notices'
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

if rebuilt.empty?
  puts 'SKIP: No build artifacts found for this version.'
  exit 0
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
nginx_files_to_edit = {}
if !rebuilt && manifest_name == 'nginx' && buildpack_name == 'nginx'
  v = SemVer.parse(resource_version)
  raise "Invalid version format: #{resource_version}" if v.nil?
  raise "When setting nginx's version_line, expected to find data['source']['version_filter'], but did not" unless data.dig('source', 'version_filter')

  if v.minor.even? # 1.12.X is stable
    manifest['version_lines']['stable'] = data['source']['version_filter'].downcase
  else
    # 1.13.X is mainline
    manifest['version_lines']['mainline'] = data['source']['version_filter'].downcase
  end

  # Update nginx integration test expectations
  # The test file contains hardcoded version strings that need to match the manifest
  test_file_path = 'src/nginx/integration/default_test.go'
  full_test_file_path = File.join('buildpack', test_file_path)
  if File.exist?(full_test_file_path)
    test_content = File.read(full_test_file_path)
    
    # Get mainline and stable major.minor versions from version_lines
    mainline_version = manifest['version_lines']['mainline']
    stable_version = manifest['version_lines']['stable']
    
    # Extract unique version lines (X.Y.x format) from dependencies
    version_lines = manifest['dependencies']
      .select { |dep| dep['name'] == 'nginx' }
      .map { |dep| dep['version'] }
      .map { |ver| ver.match(/^(\d+\.\d+)\./) }
      .compact
      .map { |m| "#{m[1]}.x" }
      .uniq
      .sort_by { |v| Gem::Version.new(v.sub(/\.x$/, '.0')) }
    
    # Create the available versions string: "mainline, stable, 1.26.x, 1.28.x, 1.29.x"
    available_versions = (['mainline', 'stable'] + version_lines).join(', ')
    
    # Update test expectations
    # 1. Update "using mainline => X.Y." pattern
    test_content.gsub!(/using mainline => \d+\.\d+\./, "using mainline => #{mainline_version.sub(/\.x$/, '.')}") if mainline_version
    
    # 2. Update "mainline => X.Y." pattern (for explicit mainline request)
    test_content.gsub!(/Requested nginx version: mainline => \d+\.\d+\./, "Requested nginx version: mainline => #{mainline_version.sub(/\.x$/, '.')}") if mainline_version
    
    # 3. Update "stable => X.Y." pattern
    test_content.gsub!(/stable => \d+\.\d+\./, "stable => #{stable_version.sub(/\.x$/, '.')}") if stable_version
    
    # 4. Update "Available versions: ..." line
    test_content.gsub!(/Available versions: [^\`]+/, "Available versions: #{available_versions}")
    
    nginx_files_to_edit[test_file_path] = test_content
    puts "Prepared nginx test expectations update for #{test_file_path}"
    puts "  Mainline: #{mainline_version}"
    puts "  Stable: #{stable_version}"
    puts "  Available versions: #{available_versions}"
  else
    puts "Warning: nginx test file not found at #{full_test_file_path}"
  end

  # Update nginx override buildpack fixture
  # The override buildpack test uses a fake nginx version to test error handling
  # The version needs to match the current mainline version line
  override_file_path = 'fixtures/util/override_buildpack/override.yml'
  full_override_file_path = File.join('buildpack', override_file_path)
  if File.exist?(full_override_file_path)
    override_content = File.read(full_override_file_path)
    
    mainline_version = manifest['version_lines']['mainline']
    
    # Extract the major.minor from mainline (e.g., "1.28.x" -> "1.28")
    if mainline_version && mainline_version.match(/^(\d+\.\d+)/)
      mainline_major_minor = $1
      fake_version = "#{mainline_major_minor}.999"  # e.g., "1.28.999"
      
      # Update version_lines.mainline
      override_content.gsub!(/^(\s*mainline:\s+)\d+\.\d+\.\d+/, "\\1#{fake_version}")
      
      # Update nginx dependency version
      override_content.gsub!(/^(\s*version:\s+)\d+\.\d+\.\d+/, "\\1#{fake_version}")
      
      # Update URI
      override_content.gsub!(/nginx-\d+\.\d+\.\d+/, "nginx-#{fake_version}")
      
      nginx_files_to_edit[override_file_path] = override_content
      puts "Prepared override buildpack fixture update for #{override_file_path}"
      puts "  Fake version: #{fake_version}"
    end
  else
    puts "Warning: override buildpack fixture not found at #{full_override_file_path}"
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
# * AppDynamics extension is now handled via manifest.yml in the Go-based buildpack
#   No additional file updates needed - version comes from manifest only

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

  nginx_files_to_edit.each do |path, content|
    if content
      File.write(path, content)
      GitClient.add_file(path)
    end
  end

  GitClient.safe_commit(commit_message.to_s)
end
