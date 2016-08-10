class BuildpackDependencyUpdater::Node < BuildpackDependencyUpdater
  def perform_dependency_update
    major_version, minor_version, _ = dependency_version.split(".")
    version_to_delete = buildpack_manifest["dependencies"].select do |dep|
      dep_maj, dep_min, _ = dep["version"].to_s.split(".")
      if major_version == "0"
        # node 0.10.x, 0.12.x
        dep_maj == major_version && dep_min == minor_version && dep["name"] == dependency
      else
        # node 4.x, 5.x, 6.x
        dep_maj == major_version && dep["name"] == dependency
      end
    end.map do |dep|
      Gem::Version.new(dep['version'])
    end.sort.first.to_s

    if buildpack == "nodejs" || (buildpack == "ruby" && major_version == "4")
      buildpack_manifest["dependencies"].delete_if { |dep| dep["name"] == dependency && dep["version"] == version_to_delete }
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

    # Make latest node 4.x.y version default node version for node buildpack
    if major_version == "4"
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
      "match" => "node-v?(d+.d+.d+)",
      "name" => dependency,
      "version" => dependency_version
    }
    buildpack_manifest["url_to_dependency_map"] << dependency_hash
  end
end
