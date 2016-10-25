require 'tmpdir'
require 'fileutils'

class BuildpackDependencyUpdater::Dotnet < BuildpackDependencyUpdater
  def dependency_version_currently_in_manifest
    dependencies = buildpack_manifest['dependencies']
    dependencies.select do |dep|
      dep['name'] == dependency &&
      dep['version'] == dependency_version &&
      dep['uri'] == uri
    end.count > 0
  end

  def get_dependency_info
    git_commit_message = GitClient.last_commit_message(binary_builds_dir)

    buildpack_dependencies_host_domain = ENV.fetch('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil)
    raise 'No host domain set via BUILDPACK_DEPENDENCIES_HOST_DOMAIN' unless buildpack_dependencies_host_domain

    /.*filename:\s+binary-builder\/(#{dependency}.(.*).linux-amd64.tar.gz).*md5:\s+(\w*)\,.*/.match(git_commit_message)
    dependency_filename = $1
    dependency_version = $2
    md5 = $3

    url ="https://#{buildpack_dependencies_host_domain}/concourse-binaries/#{dependency}/#{dependency_filename}"

    [dependency_version, url, md5]
  end

  def perform_dependency_update
    @removed_versions = []

    dependency_hash = {
      "name" => dependency,
      "version" => dependency_version,
      "uri" => uri,
      "md5" => md5,
      "cf_stacks" => ["cflinuxfs2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash
  end

  def perform_dependency_specific_changes
    framework_version = get_framework_version

    update_default_versions unless Gem::Version.new(framework_version).prerelease?

    update_dotnet_versions(framework_version)
  end

  def update_default_versions
    buildpack_manifest["default_versions"].delete_if { |dep| dep["name"] == dependency }
    default_dependency_hash = {
      "name" => dependency,
      "version" => dependency_version
    }
    buildpack_manifest["default_versions"] << default_dependency_hash
  end

  def update_dotnet_versions(framework_version)
    versions_file = File.join(buildpack_dir,'dotnet-versions.yml')
    versions = YAML.load_file(versions_file)

    version_hash = {
      'dotnet' => dependency_version,
      'framework' => framework_version
    }
    versions << version_hash

    File.write(versions_file, versions.to_yaml)
  end

  def get_framework_version
    temp = Dir.mktmpdir
    framework_version =""

    Dir.chdir(temp) do
      system "curl #{uri} -o dotnet.tar.gz"
      system 'tar -xf dotnet.tar.gz'
      framework_version = Dir['./shared/Microsoft.NETCore.App/*'].first.split('/').last
    end

    FileUtils.rm_rf(temp)
    framework_version
  end
end
