# encoding: utf-8
require 'octokit'
require 'yaml'
require_relative 'git-client'

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
    # We use the <dependency>-new.yaml file to get a list of the new
    # versions to build. For each version in this file, we make a commit to
    # <dependency>-builds.yaml with the proper build information
    # Automated deps: bower, dotnet, node, nginx, glide, godep, composer

    new_dependency_versions_file = File.join(new_releases_dir, "#{dependency}-new.yaml")
    new_dependency_versions = YAML.load_file(new_dependency_versions_file)

    dependency_builds_file = File.join(binary_builds_dir, "#{dependency}-builds.yml")

    new_dependency_versions.each do |ver|
      next if (prerelease_version?(ver) && dependency != 'dotnet')

      new_build = {"version" => ver}
      dependency_verification_tuples = DependencyBuildEnqueuer.build_verifications_for(dependency, ver)
      dependency_verification_tuples.each do |dependency_verification_type, dependency_verification_value|
        new_build[dependency_verification_type] = dependency_verification_value
      end

      File.open(dependency_builds_file, "w") do |file|
        file.write({dependency => [new_build]}.to_yaml)
      end

      Dir.chdir(binary_builds_dir) do
        GitClient.add_file(dependency_builds_file)
        commit_msg = "Enqueue #{dependency} - #{ver}"
        GitClient.safe_commit(commit_msg)
      end
    end
  end

  private

  def prerelease_version?(version)
    version = massage_version_for_semver(version)
    Gem::Version.new(version).prerelease?
  end


  def massage_version_for_semver(version)
    case dependency
      when "dotnet" then version.gsub("v","")
      when "godep" then version.gsub("v","")
      when "glide" then version.gsub("v","")
      else version
    end
  end

  def self.build_verifications_for(dependency, version)
    verifications = []
    case dependency
    when 'bower'
      download_url = "https://registry.npmjs.org/bower/-/bower-#{version}.tgz"
      verifications << shasum_256_verification(download_url)
    when "node"
      download_url = "https://nodejs.org/dist/v#{version}/node-v#{version}.tar.gz"
      verifications << shasum_256_verification(download_url)
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
    when "dotnet"
      verifications << git_commit_sha_verification('dotnet/cli', version)
    end
  end

  def self.git_commit_sha_verification(repo, version)
    t = Octokit.tags(repo).find do |t|
      t.name == version
    end
    [ 'git-commit-sha', t[:commit][:sha] ]
  end

  def self.shasum_256_verification(download_url)
    # only get the sha value and not the filename
    shasum256 = `curl -sL #{download_url} | shasum -a 256 | cut -d " " -f 1`
    ["sha256", shasum256.strip]
  end
end
