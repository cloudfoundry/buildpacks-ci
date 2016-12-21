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
    binary_built_file = "binary-built-output/#{dependency}-built.yml"
    git_commit_message = GitClient.last_commit_message(binary_built_dir, 0, binary_built_file)
    git_commit_message.gsub!(/Build(.*)\n\n/,'')
    git_commit_message.gsub!(/\n\n\[ci skip\]/,'')

    build_info = YAML.load(git_commit_message)
    dependency_filename = build_info['filename']
    md5 = build_info['md5']
    dependency_version = build_info['version'].gsub(/^v/,'')

    buildpack_dependencies_host_domain = ENV.fetch('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil)
    raise 'No host domain set via BUILDPACK_DEPENDENCIES_HOST_DOMAIN' unless buildpack_dependencies_host_domain

    url ="https://#{buildpack_dependencies_host_domain}/dependencies/#{dependency}/#{dependency_filename}"

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
