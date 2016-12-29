class BuildpackDependencyUpdater::Composer < BuildpackDependencyUpdater
  def get_dependency_info
    binary_built_file = "binary-built-output/#{dependency}-built.yml"
    git_commit_message = GitClient.last_commit_message(binary_built_dir, 0, binary_built_file)
    git_commit_message.gsub!(/Build(.*)\n\n/,'')
    git_commit_message.gsub!(/\n\n\[ci skip\]/,'')

    build_info = YAML.load(git_commit_message)
    dependency_filename = build_info['filename']
    md5 = build_info['md5']
    dependency_version = build_info['version']

    buildpack_dependencies_host_domain = ENV.fetch('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil)
    raise 'No host domain set via BUILDPACK_DEPENDENCIES_HOST_DOMAIN' unless buildpack_dependencies_host_domain

    url ="https://#{buildpack_dependencies_host_domain}/dependencies/composer/#{dependency_version}/composer.phar"

    [dependency_version, url, md5]
  end

  def perform_dependency_specific_changes
    perform_default_versions_update
  end
end
