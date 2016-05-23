# encoding: utf-8
require 'yaml'

class BuildpackManifestUpdater
  attr_reader :dependency
  attr_reader :buildpack
  attr_reader :buildpack_dir
  attr_reader :binary_builds_dir
  attr_reader :dependency_version

  def initialize(dependency, buildpack, buildpack_dir, binary_builds_dir)
    @dependency = dependency
    @buildpack = buildpack
    @buildpack_dir = buildpack_dir
    @binary_builds_dir = binary_builds_dir
    @dependency_version, @url, @md5 = BuildpackManifestUpdater.get_dependency_info(dependency, binary_builds_dir)
  end

  def run!
    manifest_file = File.join(buildpack_dir, "manifest.yml")
    buildpack_manifest = YAML.load_file(manifest_file)

    buildpack_manifest = perform_dependency_update(buildpack_manifest)
    buildpack_manifest = perform_dependency_specific_changes(buildpack_manifest, dependency)

    File.open(manifest_file, "w") do |file|
      file.write(buildpack_manifest.to_yaml)
    end
  end

  private

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

  def perform_dependency_specific_changes(buildpack_manifest, dependency)
    if dependency == "godep"
      buildpack_manifest["url_to_dependency_map"].delete_if {|dep| dep["name"] == dependency}
      dependency_hash = {
        "match"   => dependency,
        "name"    => dependency,
        "version" => dependency_version
      }
      buildpack_manifest["url_to_dependency_map"] << dependency_hash
    end
    buildpack_manifest
  end

  def self.get_dependency_info(dependency, binary_builds_dir)
    Dir.chdir(binary_builds_dir) do
      git_commit_message = `git log --format=%B -n 1 HEAD`
      case dependency
      when "godep"
        /.*filename:\s+binary-builder\/(godep-(\w*)-linux-x64.tgz).*md5:\s+(\w*)\,.*/.match(git_commit_message)
        dependency_filename = $1
        dependency_version = $2
        md5 = $3
        url = "https://pivotal-buildpacks.s3.amazonaws.com/concourse-binaries/#{dependency}/#{dependency_filename}"
      when "composer"
        /.*filename:\s+binary-builder\/composer-(\w*).phar.*md5:\s+(\w*)\,.*/.match(git_commit_message)
        dependency_version = $1
        md5 = $2
        url ="https://pivotal-buildpacks.s3.amazonaws.com/php/binaries/trusty/composer/#{dependency_version}/composer.phar"
      end
      [dependency_version, url, md5]
    end
  end
end
