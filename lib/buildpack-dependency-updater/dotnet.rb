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
    @dependency_version ||= dependency_build_info['version'].gsub(/^v/,'')
  end

  def perform_dependency_update
    @removed_versions = []

    dependency_hash = {
      "name" => dependency,
      "version" => dependency_version,
      "uri" => uri,
      "sha256" => sha256,
      "cf_stacks" => ["cflinuxfs2"]
    }
    buildpack_manifest["dependencies"] << dependency_hash
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
