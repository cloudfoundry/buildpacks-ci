class BuildpackDependencyUpdater::Node < BuildpackDependencyUpdater
  def perform_dependency_update
    major_version, minor_version, _ = dependency_version.split(".")
    version_to_delete = buildpack_manifest["dependencies"].select do |dep|
      dep_maj, dep_min, _ = dep["version"].to_s.split(".")
      if major_version == "0"
        # 0.12.x
        dep_maj == major_version && dep_min == minor_version && dep["name"] == dependency
      else
        # node 4.x, 5.x, 6.x
        dep_maj == major_version && dep["name"] == dependency
      end
    end.map do |dep|
      Gem::Version.new(dep['version'])
    end.sort.first.to_s

    original_dependencies = buildpack_manifest["dependencies"].clone
    new_dependencies = buildpack_manifest["dependencies"].clone

    if buildpack == "nodejs" || (buildpack == "ruby" && major_version == "4") || (buildpack == 'dotnet-core' && major_version == '6')
      new_dependencies = buildpack_manifest["dependencies"].delete_if { |dep| dep["name"] == dependency && dep["version"] == version_to_delete }
      dependency_hash = {
        "name" => dependency,
        "version" => dependency_version,
        "uri" => uri,
        "md5" => md5,
        "cf_stacks" => ["cflinuxfs2"]
      }
      buildpack_manifest["dependencies"] << dependency_hash
      update_version_in_url_to_dependency_map if buildpack == "ruby"
    end

    @removed_versions = (original_dependencies - new_dependencies).map{|dep| dep['version']} unless new_dependencies == original_dependencies
  end

  def perform_dependency_specific_changes
    major_version, minor_version, _ = dependency_version.split(".")

    # Make latest node 4.x.y version default node version for node buildpack & ruby buildpack
    # Make latest node 6.x.y version default node version for dotnet-core buildpack
    update_default_versions = (buildpack == "nodejs" && major_version == "4") ||
                              (buildpack == "ruby" && major_version == "4")   ||
                              (buildpack == 'dotnet-core' && major_version == '6')

    if update_default_versions
      buildpack_manifest["default_versions"].delete_if { |dep| dep["name"] == dependency }
      default_dependency_hash = {
        "name" => dependency,
        "version" => dependency_version
      }
      buildpack_manifest["default_versions"] << default_dependency_hash
    end
  end

  def update_version_in_url_to_dependency_map
    buildpack_manifest["url_to_dependency_map"].delete_if { |dep| dep["name"] == dependency }
    dependency_hash = {
      "match" => "node",
      "name" => dependency,
      "version" => dependency_version
    }
    buildpack_manifest["url_to_dependency_map"] << dependency_hash
  end

  def dependency_version_currently_in_manifest
    dependencies = buildpack_manifest['dependencies']
    dependencies.select do |dep|
      dep['name'] == dependency &&
      dep['version'] == dependency_version &&
      dep['uri'] == uri
    end.count > 0
  end
end
