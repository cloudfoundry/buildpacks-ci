# encoding: utf-8
require 'yaml'

class DependencyBuildEnqueuer
  attr_reader :dependency
  attr_reader :new_releases_dir
  attr_reader :binary_builds_dir
  attr_reader :latest_version
  attr_reader :options

  # dependency should match the name of the dependency yaml file in
  # buildpacks-ci, binary-builds branch
  def initialize(dependency, new_releases_dir, binary_builds_dir, options = {})
    @dependency = dependency
    @new_releases_dir = new_releases_dir
    @binary_builds_dir = binary_builds_dir
    @options = options
  end

  def enqueue_build
    dependency_versions_file = File.join(new_releases_dir, "#{dependency}.yaml")
    dependency_versions = YAML.load_file(dependency_versions_file)

    @latest_version = DependencyBuildEnqueuer.latest_version_for_dependency(dependency, dependency_versions, options)

    new_build = {"version" => latest_version}
    dependency_verification_tuples = DependencyBuildEnqueuer.build_verifications_for(dependency, latest_version)
    dependency_verification_tuples.each do |dependency_verification_type, dependency_verification_value|
      new_build[dependency_verification_type] = dependency_verification_value
    end

    dependency_builds_file = File.join(binary_builds_dir, "#{dependency}-builds.yml")
    File.open(dependency_builds_file, "w") do |file|
      file.write({dependency => [new_build]}.to_yaml)
    end
  end

  def self.latest_version_for_dependency(dependency, dependency_versions, options = {})
    case dependency
    when "godep"
      dependency_versions.max { |a, b| a.gsub("v", "").to_i <=> b.gsub("v", "").to_i }
    when "nginx"
      dependency_versions.map do |version|
        Gem::Version.new(version.gsub("release-", ""))
      end.sort.reverse[0].to_s
    when "composer"
      dependency_versions.map do |version|
        gem_version = Gem::Version.new(version)
        if !options[:pre]
          gem_version = gem_version.prerelease? ? nil : gem_version
        end
        gem_version
        # When you create a Gem::Version of some kind of pre-release or RC, it
        # will replace a '-' with '.pre.', e.g. "1.1.0-RC" -> #<Gem::Version "1.1.0.pre.RC">
      end.compact.sort.reverse[0].to_s.gsub(".pre.","-")
    when "glide"
      dependency_versions.map do |version|
        gem_version = Gem::Version.new(version.gsub("v", ""))
        if !options[:pre]
          gem_version = gem_version.prerelease? ? nil : gem_version
        end
        gem_version
      end.compact.sort.reverse[0].to_s.gsub(".pre.","-").prepend("v")
    end
  end

  private

  def self.build_verifications_for(dependency, version)
    verifications = []
    case dependency
    when "godep"
      download_url = "https://github.com/tools/godep/archive/#{version}.tar.gz"
      verifications << shasum_256_verification(download_url)
    when "composer"
      download_url = "https://getcomposer.org/download/#{version}/composer.phar"
      verifications << shasum_256_verification(download_url)
    when "glide"
      download_url = "https://github.com/Masterminds/glide/archive/#{version}.tar.gz"
      verifications << shasum_256_verification(download_url)
    when "nginx"
      gpg_signature_url = "http://nginx.org/download/nginx-#{version}.tar.gz.asc"
      gpg_signature = `curl -sL #{gpg_signature_url}`
      verifications << ['gpg-rsa-key-id', 'A1C052F8']
      verifications << ['gpg-signature', gpg_signature]
    end
  end

  def self.shasum_256_verification(download_url)
    # only get the sha value and not the filename
    shasum256 = `curl -sL #{download_url} | shasum -a 256 | cut -d " " -f 1`
    ["sha256", shasum256.strip]
  end
end
