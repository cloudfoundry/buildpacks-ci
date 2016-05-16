# encoding: utf-8
require 'yaml'

class DependencyBuildEnqueuer
  attr_reader :dependency
  attr_reader :new_releases_dir
  attr_reader :binary_builds_dir
  attr_reader :latest_version

  # dependency should match the name of the dependency yaml file in
  # buildpacks-ci, binary-builds branch
  def initialize(dependency, new_releases_dir, binary_builds_dir)
    @dependency = dependency
    @new_releases_dir = new_releases_dir
    @binary_builds_dir = binary_builds_dir
  end

  def enqueue_build
    dependency_versions_file = File.join(new_releases_dir, "#{dependency}.yaml")
    dependency_versions = YAML.load_file(dependency_versions_file)

    @latest_version = dependency_versions.max

    new_build = {"version" => latest_version}
    dependency_verification_type, dependency_verification_value = DependencyBuildEnqueuer.build_verification_for(dependency, latest_version)
    new_build[dependency_verification_type] = dependency_verification_value

    dependency_builds_file = File.join(binary_builds_dir, "#{dependency}-builds.yml")
    File.open(dependency_builds_file, "w") do |file|
      file.write({"godep" => [new_build]}.to_yaml)
    end
  end

  private

  def self.build_verification_for(dependency, version)
    if dependency == "godep"
      godep_download_url = "https://github.com/tools/godep/archive/#{version}.tar.gz"
      # only get the sha value and not the filename
      shasum256 = `curl -sL #{godep_download_url} | shasum -a 256 | cut -d " " -f 1`
      ["sha256", shasum256]
    end
  end
end
