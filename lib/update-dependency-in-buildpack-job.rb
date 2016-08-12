# encoding: utf-8
require_relative "buildpack-dependency-updater"
require_relative "tracker-client"
require_relative "git-client"

class UpdateDependencyInBuildpackJob
  attr_reader :buildpacks_ci_dir
  attr_reader :binary_builds_dir

  def initialize(buildpacks_ci_dir, binary_builds_dir)
    @buildpacks_ci_dir = buildpacks_ci_dir
    @binary_builds_dir = binary_builds_dir
  end

  def update_buildpack
    dependency = ENV['DEPENDENCY']
    buildpack_name = ENV['BUILDPACK_NAME']
    buildpack_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', "buildpack"))

    buildpack_updater = BuildpackDependencyUpdater.create(dependency, buildpack_name, buildpack_dir, binary_builds_dir)

    version = buildpack_updater.dependency_version

    puts "Updating manifest with #{dependency} #{version}..."
    buildpack_updater.run!
    removed_versions = buildpack_updater.removed_versions
    return buildpack_dir, dependency, version, removed_versions
  end

  def extract_source_info(git_commit_message)
    if git_commit_message.include?('gpg-signature:')
      result = /^(?<source_info>source url: .*END PGP SIGNATURE-----)/m.match(git_commit_message)
    else
      result = /^(?<source_info>source url: .*)$/.match(git_commit_message)
    end

    result['source_info']
  end

  def write_git_commit(buildpack_dir, dependency, story_ids, version, removed_versions)
    git_commit_message = GitClient.last_commit_message(binary_builds_dir)

    source_info = extract_source_info(git_commit_message)

    formatted_story_ids = story_ids.map {|story_id| "[##{story_id}]"}

    Dir.chdir(buildpack_dir) do
      GitClient.add_everything
      add_remove_message = "Add #{dependency} #{version}"
      add_remove_message += ", remove #{dependency} #{removed_versions.join(', ')}" unless removed_versions.empty?
      update_commit_message = "#{add_remove_message}\n\n#{source_info}\n\n#{formatted_story_ids.join("\n")}"
      GitClient.safe_commit(update_commit_message)
    end
  end

  def run!
    buildpack_dir, dependency, version, removed_versions = update_buildpack

    tracker_client = TrackerClient.new(ENV['TRACKER_API_TOKEN'], ENV['TRACKER_PROJECT_ID'], ENV['TRACKER_REQUESTER_ID'].to_i)
    story_ids = tracker_client.find_unaccepted_story_ids("include new #{dependency} #{version}")

    write_git_commit(buildpack_dir, dependency, story_ids, version, removed_versions)
  end
end
