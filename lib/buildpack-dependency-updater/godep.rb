class BuildpackDependencyUpdater::Godep < BuildpackDependencyUpdater
  def perform_dependency_specific_changes
    update_version_in_url_to_dependency_map
  end
end
