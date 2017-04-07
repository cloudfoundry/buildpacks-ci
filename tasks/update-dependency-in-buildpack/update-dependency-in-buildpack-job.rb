# encoding: utf-8
require 'yaml'
require_relative "../../lib/buildpack-dependency-updater"
require_relative "../../lib/git-client"

class UpdateDependencyInBuildpackJob
  attr_reader :buildpacks_ci_dir
  attr_reader :binary_built_out_dir

  def initialize(buildpacks_ci_dir, binary_built_out_dir)
    @buildpacks_ci_dir = buildpacks_ci_dir
    @binary_built_out_dir = binary_built_out_dir
  end

  def update_buildpack
    dependency = ENV.fetch('DEPENDENCY')
    buildpack_name = ENV.fetch('BUILDPACK_NAME')
    stack_name = ENV.fetch('STACK_NAME')
    buildpack_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', "buildpack-input"))

    buildpack_updater = BuildpackDependencyUpdater.create(dependency, stack_name, buildpack_name, buildpack_dir, binary_built_out_dir)

    version = buildpack_updater.dependency_version

    puts "Updating manifest for #{stack_name} stack with #{dependency} #{version}..."
    buildpack_updater.run!
    removed_versions = buildpack_updater.removed_versions
    return buildpack_dir, dependency, version, removed_versions
  end

  def extract_source_info(git_commit_message)
    git_commit_message.gsub!(/Build(.*)\n\n/,'')
    git_commit_message.gsub!(/\n\n\[ci skip\]/,'')

    build_info = YAML.load(git_commit_message)

    build_info.select do |k,v|
      k.include?('source')
    end
  end

  def write_git_commit(buildpack_dir, dependency, version, removed_versions)
    binary_built_file = "binary-built-output/#{dependency}-built.yml"
    git_commit_message = GitClient.last_commit_message(binary_built_out_dir, 0, binary_built_file)

    source_info = ""

    extract_source_info(git_commit_message).each do |k,v|
      source_info+= "#{k}: #{v}\n"
    end

    Dir.chdir(buildpack_dir) do
      GitClient.add_everything
      add_remove_message = "Add #{dependency} #{version}"
      add_remove_message += ", remove #{dependency} #{removed_versions.join(', ')}" unless removed_versions.empty?
      update_commit_message = "#{add_remove_message}\n\n#{source_info}\n"
      GitClient.safe_commit(update_commit_message)
    end
  end

  def run!
    buildpack_dir, dependency, version, removed_versions = update_buildpack

    write_git_commit(buildpack_dir, dependency, version, removed_versions)
  end
end
