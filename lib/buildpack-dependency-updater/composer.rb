class BuildpackDependencyUpdater::Composer < BuildpackDependencyUpdater
  def uri
    return @uri if @uri

    dependency_filename = dependency_build_info['filename']

    buildpack_dependencies_host_domain = ENV.fetch('BUILDPACK_DEPENDENCIES_HOST_DOMAIN', nil)
    raise 'No host domain set via BUILDPACK_DEPENDENCIES_HOST_DOMAIN' unless buildpack_dependencies_host_domain

    @uri = "https://#{buildpack_dependencies_host_domain}/dependencies/composer/#{dependency_version}/composer.phar"
  end

  def perform_dependency_specific_changes
    perform_default_versions_update
  end
end
