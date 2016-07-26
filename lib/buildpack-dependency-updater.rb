# encoding: utf-8
require 'yaml'
require_relative 'git-client'

class BuildpackDependencyUpdater
  attr_reader :dependency
  attr_reader :buildpack
  attr_reader :buildpack_dir
  attr_reader :binary_builds_dir
  attr_reader :dependency_version

  def self.create(dependency, *args)
    raise "Unsupported dependency" unless const_defined? dependency.capitalize
    const_get(dependency.capitalize).new(dependency, *args)
  end

  def initialize(dependency, buildpack, buildpack_dir, binary_builds_dir)
    @dependency = dependency
    @buildpack = buildpack
    @buildpack_dir = buildpack_dir
    @binary_builds_dir = binary_builds_dir
    @dependency_version, @url, @md5 = get_dependency_info
  end

  def run!
    manifest_file = File.join(buildpack_dir, "manifest.yml")
    buildpack_manifest = YAML.load_file(manifest_file)

    buildpack_manifest = perform_dependency_update(buildpack_manifest)
    buildpack_manifest = perform_dependency_specific_changes(buildpack_manifest)

    File.open(manifest_file, "w") do |file|
      file.write(buildpack_manifest.to_yaml)
    end
  end

  private

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

  def perform_dependency_update(buildpack_manifest)
    buildpack_manifest["dependencies"].delete_if {|dep| dep["name"] == dependency}

    dependency_hash = {
      "name"      => dependency,
      "version"   => dependency_version,
      "uri"       => @url,
      "md5"       => @md5,
      "cf_stacks" => ["cflinuxfs2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash
    buildpack_manifest
  end

  def update_version_in_url_to_dependency_map(buildpack_manifest)
    buildpack_manifest["url_to_dependency_map"].delete_if {|dep| dep["name"] == dependency}
    dependency_hash = {
      "match"   => dependency,
      "name"    => dependency,
      "version" => dependency_version
    }
    buildpack_manifest["url_to_dependency_map"] << dependency_hash
    buildpack_manifest
  end

  def perform_dependency_specific_changes(buildpack_manifest)
    buildpack_manifest
  end
end


class BuildpackDependencyUpdater::Godep < BuildpackDependencyUpdater
  def perform_dependency_specific_changes(buildpack_manifest)
    update_version_in_url_to_dependency_map(buildpack_manifest)
  end
end

class BuildpackDependencyUpdater::Glide < BuildpackDependencyUpdater
  def perform_dependency_specific_changes(buildpack_manifest)
    update_version_in_url_to_dependency_map(buildpack_manifest)
  end
end

class BuildpackDependencyUpdater::Composer < BuildpackDependencyUpdater
  def get_dependency_info
    git_commit_message = GitClient.last_commit_message(binary_builds_dir)

    buildpack_dependencies_host_domain = ENV.fetch('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil)
    raise 'No host domain set via BUILDPACK_DEPENDENCIES_HOST_DOMAIN' unless buildpack_dependencies_host_domain

    dependency_version = git_commit_message[/filename:\s+binary-builder\/composer-([\d\.]*).phar/, 1]
    md5 = git_commit_message[/md5:\s+(\w+)/, 1]
    url ="https://#{buildpack_dependencies_host_domain}/php/binaries/trusty/composer/#{dependency_version}/composer.phar"

    [dependency_version, url, md5]
  end
end

class BuildpackDependencyUpdater::Nginx < BuildpackDependencyUpdater
  def update_version_in_url_to_dependency_map(buildpack_manifest)
    if mainline_version?(dependency_version) && buildpack == "staticfile"
      buildpack_manifest["url_to_dependency_map"].delete_if {|dep| dep["name"] == dependency}
      dependency_hash = {
        "match"   => "#{dependency}.tgz",
        "name"    => dependency,
        "version" => dependency_version
      }
      buildpack_manifest["url_to_dependency_map"] << dependency_hash
    end
    buildpack_manifest
  end

  def perform_dependency_specific_changes(buildpack_manifest)
    if buildpack == 'php' && dependency_version.split(".")[1].to_i.odd?
      options = File.read(File.join(buildpack_dir, "defaults", "options.json"))
      /\"(NGINX\w+LATEST)\":.*/.match(options)
      new_default = options.gsub(/\"NGINX\w+LATEST\":.*/, "\"#{$1}\": \"#{dependency_version}\",")
      File.open(File.join(buildpack_dir, "defaults", "options.json"),"w") {|file| file.puts new_default}
    end

    update_version_in_url_to_dependency_map(buildpack_manifest)
  end

  def perform_dependency_update(buildpack_manifest)
    if mainline_version?(dependency_version)
      buildpack_manifest["dependencies"].delete_if {|dep| dep["name"] == dependency && mainline_version?(dep["version"])}
    elsif stable_version?(dependency_version) && buildpack == 'php'
      buildpack_manifest["dependencies"].delete_if {|dep| dep["name"] == dependency && stable_version?(dep["version"])}
    elsif buildpack == 'staticfile'
      return buildpack_manifest
    end

    dependency_hash = {
      "name"      => dependency,
      "version"   => dependency_version,
      "uri"       => @url,
      "md5"       => @md5,
      "cf_stacks" => ["cflinuxfs2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash
    buildpack_manifest
  end

  def mainline_version?(version)
    version.split(".")[1].to_i.odd?
  end

  def stable_version?(version)
    !mainline_version?(version)
  end
end

class BuildpackDependencyUpdater::Node < BuildpackDependencyUpdater
  def perform_dependency_update(buildpack_manifest)
    major_version, minor_version, _ = dependency_version.split(".")
    version_to_delete = buildpack_manifest["dependencies"].select do |dep|
      dep_maj, dep_min, _ = dep["version"].split(".")

      if major_version == "0"
        # node 0.10.x, 0.12.x
        dep_maj == major_version && dep_min == minor_version && dep["name"] == dependency
      else
        # node 4.x, 5.x, 6.x
        dep_maj == major_version && dep["name"] == dependency
      end
    end.map do |dep|
      Gem::Version.new(dep['version'])
    end.sort.first.to_s

    if buildpack == "nodejs" || (buildpack == "ruby" && major_version == "4")
      buildpack_manifest["dependencies"].delete_if {|dep| dep["name"] == dependency && dep["version"] == version_to_delete}
      dependency_hash = {
        "name"      => dependency,
        "version"   => dependency_version,
        "uri"       => @url,
        "md5"       => @md5,
        "cf_stacks" => ["cflinuxfs2"]
      }
      buildpack_manifest["dependencies"] << dependency_hash
      buildpack_manifest = update_version_in_url_to_dependency_map(buildpack_manifest) if buildpack == "ruby"
    end

    # Make latest node 4.x.y version default node version for node buildpack
    if major_version == "4"
      buildpack_manifest["default_versions"].delete_if {|dep| dep["name"] == dependency}
      default_dependency_hash = {
        "name"    => dependency,
        "version" => dependency_version
      }
      buildpack_manifest["default_versions"] << default_dependency_hash
    end
    buildpack_manifest
  end

  def update_version_in_url_to_dependency_map(buildpack_manifest)
    buildpack_manifest["url_to_dependency_map"].delete_if {|dep| dep["name"] == dependency}
    dependency_hash = {
      "match"   => "node-v?(d+.d+.d+)",
      "name"    => dependency,
      "version" => dependency_version
    }
    buildpack_manifest["url_to_dependency_map"] << dependency_hash
    buildpack_manifest
  end
end

