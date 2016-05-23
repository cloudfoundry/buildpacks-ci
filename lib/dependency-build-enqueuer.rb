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

    @latest_version = DependencyBuildEnqueuer.latest_version_for_dependency(dependency, dependency_versions)

    new_build = {"version" => latest_version}
    dependency_verification_type, dependency_verification_value = DependencyBuildEnqueuer.build_verification_for(dependency, latest_version)
    new_build[dependency_verification_type] = dependency_verification_value

    dependency_builds_file = File.join(binary_builds_dir, "#{dependency}-builds.yml")
    File.open(dependency_builds_file, "w") do |file|
      file.write({dependency => [new_build]}.to_yaml)
    end
  end

  def self.latest_version_for_dependency(dependency, dependency_versions)
    case dependency
    when "godep"
      dependency_versions.max { |a, b| a.gsub("v", "").to_i <=> b.gsub("v", "").to_i }
    when "composer"
      dependency_versions.map do |version|
        Gem::Version.new(version)
      end.sort.reverse[0].to_s.gsub(".pre.","-")
    end
  end

  private

  def self.build_verification_for(dependency, version)
    case dependency
    when "godep"
      download_url = "https://github.com/tools/godep/archive/#{version}.tar.gz"
    when "composer"
      download_url = "https://getcomposer.org/download/#{version}/composer.phar"
    end
    # only get the sha value and not the filename
    shasum256 = `curl -sL #{download_url} | shasum -a 256 | cut -d " " -f 1`
    ["sha256", shasum256.strip]
  end
end
