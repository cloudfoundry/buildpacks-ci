class BuildpackDependencyUpdater::Bower < BuildpackDependencyUpdater
  def perform_dependency_specific_changes
    buildpack_manifest['default_versions'].delete_if { |dep| dep['name'] == dependency }

    default_dependency_hash = {
        'name' => dependency,
        'version' => dependency_version
    }

    buildpack_manifest['default_versions'] << default_dependency_hash
  end
end
