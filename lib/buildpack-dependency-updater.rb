# encoding: utf-8
require 'yaml'
require_relative 'git-client'

class BuildpackDependencyUpdater;
end

require_relative 'buildpack-dependency-updater/bundler.rb'
require_relative 'buildpack-dependency-updater/godep.rb'
require_relative 'buildpack-dependency-updater/dep.rb'
require_relative 'buildpack-dependency-updater/glide.rb'
require_relative 'buildpack-dependency-updater/bower.rb'
require_relative 'buildpack-dependency-updater/composer.rb'
require_relative 'buildpack-dependency-updater/dotnet.rb'
require_relative 'buildpack-dependency-updater/dotnet-runtime.rb'
require_relative 'buildpack-dependency-updater/nginx.rb'
require_relative 'buildpack-dependency-updater/node.rb'
require_relative 'buildpack-dependency-updater/yarn.rb'
require_relative 'buildpack-dependency-updater/hwc.rb'

class BuildpackDependencyUpdater
  attr_reader :dependency
  attr_reader :buildpack
  attr_reader :buildpack_dir
  attr_reader :previous_buildpack_dir
  attr_reader :binary_built_dir
  attr_reader :removed_versions
  attr_accessor :buildpack_manifest
  attr_accessor :previous_buildpack_manifest

  def self.create(dependency, *args)
    subclass = dependency.split('-').map { |s| s.capitalize }.join('')
    raise "Unsupported dependency" unless const_defined? subclass
    const_get(subclass).new(dependency, *args)
  end

  def initialize(dependency, buildpack, buildpack_dir, previous_buildpack_dir, binary_built_dir)
    @dependency = dependency
    @buildpack = buildpack
    @buildpack_dir = buildpack_dir
    @previous_buildpack_dir = previous_buildpack_dir
    @binary_built_dir = binary_built_dir
    @removed_versions = []
  end

  def run!
    manifest_file = File.join(buildpack_dir, "manifest.yml")
    @buildpack_manifest = YAML.load_file(manifest_file)

    previous_manifest_file = File.join(previous_buildpack_dir, "manifest.yml")
    @previous_buildpack_manifest = YAML.load_file(previous_manifest_file) if File.exists?(previous_manifest_file)

    if dependency_version_currently_in_manifest?
      puts "#{dependency} #{dependency_version} is already in the manifest for the #{buildpack} buildpack."
      puts 'No updates will be made to the manifest or buildpack.'
    elsif newer_dependency_version_currently_in_manifest?
      puts "#{dependency} #{dependency_version} is older than the one in the manifest for the #{buildpack} buildpack."
      puts 'No updates will be made to the manifest or buildpack.'
    else
      puts "Attempting to add #{dependency} #{dependency_version} to the #{buildpack} buildpack and manifest."

      perform_dependency_update
      perform_dependency_specific_changes

      File.open(manifest_file, "w") do |file|
        file.write(buildpack_manifest.to_yaml)
      end
    end
  end

  def dependency_version
    @depencency_version ||= dependency_build_info['version']
  end

  def sha256
    @sha256 ||= dependency_build_info['sha256']
  end

  def uri
    return @uri if @uri

    dependency_filename = dependency_build_info['filename']

    buildpack_dependencies_host_domain = ENV.fetch('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil)
    raise 'No host domain set via BUILDPACK_DEPENDENCIES_HOST_DOMAIN' unless buildpack_dependencies_host_domain

    @uri = "https://#{buildpack_dependencies_host_domain}/dependencies/#{dependency}/#{dependency_filename}"
  end

  private

  def newer_dependency_version_currently_in_manifest?
    dependencies = buildpack_manifest['dependencies']
    dependencies.select do |dep|
      newer_version = Gem::Version.new(dep['version'].gsub(/^v/, '')) > Gem::Version.new(dependency_version.gsub(/^v/, '')) rescue false
      dep['name'] == dependency && newer_version
    end.count > 0
  end

  def dependency_version_currently_in_manifest?
    dependencies = buildpack_manifest['dependencies']
    dependencies.select do |dep|
      dep['name'] == dependency &&
        dep['version'] == dependency_version &&
        dep['uri'] == uri &&
        dep['sha256'] == sha256
    end.count > 0
  end

  def dependency_build_info
    return @dependency_build_info if @dependency_build_info

    binary_built_file = "binary-built-output/#{dependency}-built.yml"
    git_commit_message = GitClient.last_commit_message(binary_built_dir, 0, binary_built_file)
    git_commit_message.gsub!(/Build(.*)\n\n/, '')
    git_commit_message.gsub!(/\n\n\[ci skip\]/, '')

    @dependency_build_info = YAML.load(git_commit_message)
  end


  def perform_dependency_update
    original_dependencies = buildpack_manifest["dependencies"].clone
    new_dependencies = buildpack_manifest["dependencies"].delete_if { |dep| dep["name"] == dependency }
    @removed_versions = (original_dependencies - new_dependencies).map { |dep| dep['version'] } unless new_dependencies == original_dependencies

    dependency_hash = {
      "name" => dependency,
      "version" => dependency_version,
      "uri" => uri,
      "sha256" => sha256,
      "cf_stacks" => ["cflinuxfs2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash
  end

  def update_version_in_url_to_dependency_map
    buildpack_manifest["url_to_dependency_map"].delete_if { |dep| dep["name"] == dependency }
    dependency_hash = {
      "match" => dependency,
      "name" => dependency,
      "version" => dependency_version
    }
    buildpack_manifest["url_to_dependency_map"] << dependency_hash
  end

  def perform_dependency_specific_changes;
  end

  def perform_default_versions_update
    buildpack_manifest["default_versions"].each do |dep|
      if dep["name"] == dependency
        if Gem::Version.new(dependency_version) > Gem::Version.new(dep['version'])
          dep['version'] = dependency_version
        end
      end
    end
  end
end

