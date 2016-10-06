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
    original_dependencies = buildpack_manifest["dependencies"].clone

    oldest_version = find_oldest_version(buildpack_manifest["dependencies"].map {|dep| dep['version'] })

    new_dependencies = buildpack_manifest["dependencies"].delete_if { |dep| dep["name"] == dependency  && dep['version'] == oldest_version}

    @removed_versions = (original_dependencies - new_dependencies).map{|dep| dep['version']} unless new_dependencies == original_dependencies

    dependency_hash = {
      "name" => dependency,
      "version" => dependency_version,
      "uri" => uri,
      "md5" => md5,
      "cf_stacks" => ["cflinuxfs2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash
  end

  def find_oldest_version(versions)
    versions.sort do |v1, v2|
      Gem::Version.new(v1) <=> Gem::Version.new(v2)
    end.first
  end

  def perform_dependency_specific_changes
    update_default_versions
    update_dotnet_versions
  end

  def update_default_versions
    buildpack_manifest["default_versions"].delete_if { |dep| dep["name"] == dependency }
    default_dependency_hash = {
      "name" => dependency,
      "version" => dependency_version
    }
    buildpack_manifest["default_versions"] << default_dependency_hash
  end

  def update_dotnet_versions
    framework_version = get_framework_version

    versions_file = File.join(buildpack_dir,'dotnet-versions.yml')
    versions = YAML.load_file(versions_file)

    oldest_version = find_oldest_version(versions.map { |v| v['dotnet']})
    versions.delete_if { |v| v['dotnet'] == oldest_version }

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
