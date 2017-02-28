require 'tmpdir'
require 'fileutils'

class BuildpackDependencyUpdater::Dotnet < BuildpackDependencyUpdater
  def dependency_version_currently_in_manifest?
    dependencies = buildpack_manifest['dependencies']
    dependencies.select do |dep|
      dep['name'] == dependency &&
      dep['version'] == dependency_version &&
      dep['uri'] == uri
    end.count > 0
  end

  def newer_dependency_version_currently_in_manifest?
    false
  end

  def dependency_version
    @dependency_version ||= dependency_build_info['version'].gsub(/^v/,'')
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
    perform_default_versions_update if project_json?

    update_dotnet_sdk_tools
  end

  def update_dotnet_sdk_tools
    tools_file = File.join(buildpack_dir,'dotnet-sdk-tools.yml')
    tools = YAML.load_file(tools_file)

    if project_json?
      tools['project_json'].push dependency_version
    else
      tools['msbuild'].push dependency_version
    end

    File.write(tools_file, tools.to_yaml)
  end

  def project_json?
    dependency_version.include?('preview1') || dependency_version.include?('preview2')
  end
end
