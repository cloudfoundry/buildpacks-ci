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

    perform_default_versions_update unless Gem::Version.new(framework_version).prerelease?

    update_dotnet_versions(framework_version)
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
