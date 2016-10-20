# encoding: utf-8
require 'yaml'
require_relative 'git-client'

class BuildpackDependencyUpdater; end

require_relative 'buildpack-dependency-updater/godep.rb'
require_relative 'buildpack-dependency-updater/glide.rb'
require_relative 'buildpack-dependency-updater/bower.rb'
require_relative 'buildpack-dependency-updater/composer.rb'
require_relative 'buildpack-dependency-updater/dotnet.rb'
require_relative 'buildpack-dependency-updater/nginx.rb'
require_relative 'buildpack-dependency-updater/node.rb'

class BuildpackDependencyUpdater
  attr_reader :dependency
  attr_reader :buildpack
  attr_reader :buildpack_dir
  attr_reader :binary_builds_dir
  attr_reader :dependency_version
  attr_reader :md5
  attr_reader :uri
  attr_reader :removed_versions
  attr_accessor :buildpack_manifest

  def self.create(dependency, *args)
    raise "Unsupported dependency" unless const_defined? dependency.capitalize
    const_get(dependency.capitalize).new(dependency, *args)
  end

  def initialize(dependency, buildpack, buildpack_dir, binary_builds_dir)
    @dependency = dependency
    @buildpack = buildpack
    @buildpack_dir = buildpack_dir
    @binary_builds_dir = binary_builds_dir
    @removed_versions = []
    @dependency_version, @uri, @md5 = get_dependency_info
  end

  def run!
    manifest_file = File.join(buildpack_dir, "manifest.yml")
    @buildpack_manifest = YAML.load_file(manifest_file)

    if !dependency_version_currently_in_manifest
      puts "Attempting to add #{dependency} #{dependency_version} to the #{buildpack} buildpack and manifest."

      perform_dependency_update
      perform_dependency_specific_changes

      File.open(manifest_file, "w") do |file|
        file.write(buildpack_manifest.to_yaml)
      end
    else
      puts "#{dependency} #{dependency_version} is already in the manifest for the #{buildpack} buildpack."
      puts 'No updates will be made to the manifest or buildpack.'
    end
  end

  private

  def dependency_version_currently_in_manifest
    dependencies = buildpack_manifest['dependencies']
    dependencies.select do |dep|
      dep['name'] == dependency &&
      dep['version'] == dependency_version &&
      dep['uri'] == uri &&
      dep['md5'] == md5
    end.count > 0
  end

  def get_dependency_info
    git_commit_message = GitClient.last_commit_message(binary_builds_dir)

    buildpack_dependencies_host_domain = ENV.fetch('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil)
    raise 'No host domain set via BUILDPACK_DEPENDENCIES_HOST_DOMAIN' unless buildpack_dependencies_host_domain

    /.*filename:\s+binary-builder\/(#{dependency}-(.*)-linux-x64.tgz).*md5:\s+(\w*)\,.*/.match(git_commit_message)
    dependency_filename = $1
    dependency_version = $2
    md5 = $3

    url ="https://#{buildpack_dependencies_host_domain}/concourse-binaries/#{dependency}/#{dependency_filename}"

    [dependency_version, url, md5]
  end

  def perform_dependency_update
    original_dependencies = buildpack_manifest["dependencies"].clone
    new_dependencies = buildpack_manifest["dependencies"].delete_if {|dep| dep["name"] == dependency}
    @removed_versions = (original_dependencies - new_dependencies).map{|dep| dep['version']} unless new_dependencies == original_dependencies

    dependency_hash = {
      "name"      => dependency,
      "version"   => dependency_version,
      "uri"       => @uri,
      "md5"       => @md5,
      "cf_stacks" => ["cflinuxfs2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash
  end

  def update_version_in_url_to_dependency_map
    buildpack_manifest["url_to_dependency_map"].delete_if {|dep| dep["name"] == dependency}
    dependency_hash = {
      "match"   => dependency,
      "name"    => dependency,
      "version" => dependency_version
    }
    buildpack_manifest["url_to_dependency_map"] << dependency_hash
  end

  def perform_dependency_specific_changes; end
end

