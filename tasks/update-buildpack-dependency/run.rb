#!/usr/bin/env ruby
require 'json'
require 'yaml'
require 'tmpdir'
require_relative './dependencies'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require_relative "#{buildpacks_ci_dir}/lib/git-client"

manifest = YAML.load_file('buildpack/manifest.yml')
manifest_master = YAML.load_file('buildpack-master/manifest.yml') # rescue { 'dependencies' => [] }

data = JSON.parse(open('source/data.json').read)
source_name = data.dig('source', 'name')
resource_version = data.dig('version', 'ref')
build = JSON.parse(open("builds/binary-builds-new/#{source_name}/#{resource_version}.json").read)
manifest_name = source_name == 'nginx-static' ? 'nginx' : source_name
story_id = build['tracker_story_id']
version = build['version']

system('rsync -a buildpack/ artifacts/')
raise 'Could not copy buildpack to artifacts' unless $?.success?

dep = {
  'name' => manifest_name,
  'version' => version,
  'uri' => build['url'],
  'sha256' => build['sha256'],
  'cf_stacks' => ENV['CF_STACKS'].split
}


old_versions = manifest['dependencies']
                   .select {|d| d['name'] == manifest_name}
                   .map {|d| d['version']}

manifest['dependencies'] = Dependencies.new(
    dep,
    ENV['VERSION_LINE'],
    ENV['REMOVAL_STRATEGY'],
    manifest['dependencies'],
    manifest_master['dependencies']
).switch

new_versions = manifest['dependencies']
                   .select {|d| d['name'] == manifest_name}
                   .map {|d| d['version']}

added = (new_versions - old_versions).uniq.sort
removed = (old_versions - new_versions).uniq.sort
rebuilt = old_versions.include?(version)

if added.length == 0 && !rebuilt
  puts 'SKIP: Built version is not required by buildpack.'
  exit 0
end

#
# Special PHP stuff
# * The defaults/options.json file contains default version numbers to use for each PHP line.
#   Update the default version for the relevant line to this version of PHP (if !rebuilt)
php_defaults = nil
if !rebuilt && manifest_name == 'php' && manifest['language'] == 'php'
  case version
  when /^5.6/
    varname = 'PHP_56_LATEST'
  when /^7.0/
    varname = 'PHP_70_LATEST'
  when /^7.1/
    varname = 'PHP_71_LATEST'
  when /^7.2/
    varname = 'PHP_72_LATEST'
  else
    puts "Unexpected version #{version} is not in known version lines."
    exit 1
  end

  php_defaults = JSON.load_file('buildpack/defaults/options.json')
  php_defaults[varname] = version
end

#
# Special PHP stuff
# * Each php version in the manifest lists the modules it was built with.
#   Get that list for this version of php.
if manifest_name == 'php' && manifest['language'] == 'php'
  dependencies = manifest['dependencies'].map do |dependency|
    if dependency.fetch('name') == 'php' && dependency.fetch('version') == version
      modules = Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          `wget --no-verbose #{build['url']} && tar xzf #{File.basename(build['url'])}`
          Dir['php/lib/php/extensions/no-debug-non-zts-*/*.so'].collect do |file|
            File.basename(file, '.so')
          end.sort.reject do |m|
            %w(odbc gnupg).include?(m)
          end
        end
      end
      dependency["modules"] = modules
    end
    dependency
  end
end

#
# Special PHP stuff
# * The appdynamics extension for PHP has a python file with its version number in it.
#   Replace the old version number with the new version we're adding. (if !rebuilt)
path_to_extensions = 'extensions/appdynamics/extension.py'
write_extensions = ''
if !rebuilt && manifest_name == 'appdynamics' && manifest['language'] == 'php'
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
ruby_files_to_edit = {'fixtures/sinatra_jruby/Gemfile' => nil, 'fixtures/jruby_start_command/Gemfile' => nil}
if !rebuilt && manifest_name == 'jruby' && manifest['language'] == 'ruby'
  version_number = /(9.2.\d+.\d+)_ruby-2.5/.match(version)
  if version_number
    jruby_version = version_numbers[1]
    ruby_files_to_edit.each_key do |path|
      text = File.read(File.join('buildpack', path))
      ruby_files_to_edit[path] = text.gsub(/=> '(9.2.\d+.\d+)'/, "=> '#{jruby_version}'")
    end
  end
end

commit_message = "Add #{manifest_name} #{version}"
if rebuilt
  commit_message = "Rebuild #{manifest_name} #{version}"
end
if removed.length > 0
  commit_message = "#{commit_message}, remove #{manifest_name} #{removed.join(', ')}"
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
