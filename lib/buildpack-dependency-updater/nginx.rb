class BuildpackDependencyUpdater::Nginx < BuildpackDependencyUpdater
  def update_version_in_url_to_dependency_map
    if mainline_version?(dependency_version) && buildpack == "staticfile"
      buildpack_manifest["url_to_dependency_map"].delete_if { |dep| dep["name"] == dependency }
      dependency_hash = {
        "match" => "#{dependency}.tgz",
        "name" => dependency,
        "version" => dependency_version
      }
      buildpack_manifest["url_to_dependency_map"] << dependency_hash
    end
  end

  def perform_dependency_specific_changes
    if buildpack == 'php' && mainline_version?(dependency_version)
      buildpack_manifest["default_versions"].delete_if { |dep| dep["name"] == dependency }
      default_dependency_hash = {
        "name" => dependency,
        "version" => dependency_version
      }
      buildpack_manifest["default_versions"] << default_dependency_hash
    end

    update_version_in_url_to_dependency_map
  end

  def perform_dependency_update
    original_dependencies = buildpack_manifest["dependencies"].clone

    if mainline_version?(dependency_version)
      new_dependencies = buildpack_manifest["dependencies"].delete_if { |dep| dep["name"] == dependency && mainline_version?(dep["version"]) }
    elsif stable_version?(dependency_version) && buildpack == 'php'
      new_dependencies = buildpack_manifest["dependencies"].delete_if { |dep| dep["name"] == dependency && stable_version?(dep["version"]) }
    elsif buildpack == 'staticfile'
      return
    end
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

  def mainline_version?(version)
    version.split(".")[1].to_i.odd?
  end

  def stable_version?(version)
    !mainline_version?(version)
  end
end
