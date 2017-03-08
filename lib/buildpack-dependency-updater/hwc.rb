class BuildpackDependencyUpdater::Hwc < BuildpackDependencyUpdater
  def perform_dependency_update
    original_dependencies = buildpack_manifest["dependencies"].clone
    new_dependencies = buildpack_manifest["dependencies"].delete_if {|dep| dep["name"] == dependency}
    @removed_versions = (original_dependencies - new_dependencies).map{|dep| dep['version']} unless new_dependencies == original_dependencies

    dependency_hash = {
      "name"      => dependency,
      "version"   => dependency_version,
      "uri"       => uri,
      "md5"       => md5,
      "cf_stacks" => ["windows2012R2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash
  end

  def perform_dependency_specific_changes
    perform_default_versions_update
  end
end
