require 'tmpdir'
require 'fileutils'

class BuildpackDependencyUpdater::Dotnet < BuildpackDependencyUpdater
  def dependency_version_currently_in_manifest?
    dependencies = buildpack_manifest['dependencies']
    dependencies.select do |dep|
      dep['name'] == dependency &&
        dep['version'] == dependency_version &&
        dep['uri'] == uri
    end.count > 0
  end

  def newer_dependency_version_currently_in_manifest?
    false
  end

  def dependency_version
    @dependency_version ||= dependency_build_info['version'].gsub(/^v/, '')
  end

  def perform_dependency_update
    @removed_versions = []

    dependencies_with_same_major_minor_version = get_dependencies_with_same_major_minor_version(buildpack_manifest, dependency_version)

    previous_dependencies_with_same_major_minor_version = get_dependencies_with_same_major_minor_version(previous_buildpack_manifest, dependency_version)

    if dependencies_with_same_major_minor_version.count > 1
      version_to_delete = dependencies_with_same_major_minor_version.sort.first.to_s == previous_dependencies_with_same_major_minor_version.sort.last.to_s ? dependencies_with_same_major_minor_version.sort[1].to_s : dependencies_with_same_major_minor_version.sort.first.to_s
    else
      version_to_delete = nil
    end

    original_dependencies = buildpack_manifest["dependencies"].clone
    new_dependencies = buildpack_manifest["dependencies"].delete_if { |dep| dep["name"] == dependency && dep["version"] == version_to_delete }

    dependency_hash = {
      "name" => dependency,
      "version" => dependency_version,
      "uri" => uri,
      "sha256" => sha256,
      "cf_stacks" => ["cflinuxfs2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash

    @removed_versions = (original_dependencies - new_dependencies).map { |dep| dep['version'] } unless new_dependencies == original_dependencies
  end

  def perform_dependency_specific_changes
    perform_default_versions_update
  end

  def perform_default_versions_update
    buildpack_manifest["default_versions"].each do |dep|
      if dep["name"] == dependency

        if Gem::Version.new(dependency_version) >= Gem::Version.new(semver_version(dep['version']))
          dep['version'] = dependency_version
        end
      end
    end
  end

  private

  def get_dependencies_with_same_major_minor_version(manifest, version)
    major_version, minor_version, _ = version.split(".")
    manifest["dependencies"].select do |dep|
      dep_major, dep_minor, _ = dep["version"].split(".")
      dep["name"] == dependency && dep_major == major_version && dep_minor == minor_version
    end.map do |dep|
      Gem::Version.new(dep['version'])
    end
  end

  def semver_version(version)
    version_numbers = version.split('.')
    index = version_numbers.index('x')
    if index
      version_numbers[index] = '0'
      version_numbers[index - 1].next!
    end
    version_numbers.join('.')
  end
end
