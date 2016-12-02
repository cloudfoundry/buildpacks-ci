class BuildpackDependencyUpdater::Composer < BuildpackDependencyUpdater
  def get_dependency_info
    git_commit_message = GitClient.last_commit_message(binary_builds_dir)

    buildpack_dependencies_host_domain = ENV.fetch('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil)
    raise 'No host domain set via BUILDPACK_DEPENDENCIES_HOST_DOMAIN' unless buildpack_dependencies_host_domain

    dependency_version = git_commit_message[/filename:\s+binary-builder\/composer-([\d\.]*).phar/, 1]
    md5 = git_commit_message[/md5:\s+(\w+)/, 1]
    url ="https://#{buildpack_dependencies_host_domain}/dependencies/php/binaries/trusty/composer/#{dependency_version}/composer.phar"

    [dependency_version, url, md5]
  end

  def perform_dependency_specific_changes
    perform_default_versions_update
  end
end
