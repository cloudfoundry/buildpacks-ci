# encoding: utf-8
require 'tracker_api'

class BuildpackReleaseStoryCreator
  attr_reader :buildpack_name, :previous_buildpack_version,
              :tracker_requester_id, :buildpack_project

  def initialize(buildpack_name:, previous_buildpack_version:, tracker_project_id:,
                 tracker_requester_id:, tracker_api_token:)
    @buildpack_name = buildpack_name
    @previous_buildpack_version = previous_buildpack_version
    @tracker_requester_id = tracker_requester_id

    tracker_client = TrackerApi::Client.new(token: tracker_api_token)
    @buildpack_project = tracker_client.project(tracker_project_id)
  end

  def run!
    new_release_version = previous_buildpack_version.succ
    story_name = "**Release:** #{buildpack_name}-buildpack #{new_release_version}"

    story_description = stories_since_last_release.inject("Stories:\n\n") do |story_text, story|
      story_text += "##{story.id} - #{story.name}\n"
    end
    story_description += "\nRefer to [release instructions](https://docs.cloudfoundry.org/buildpacks/releasing_a_new_buildpack_version.html).\n"

    buildpack_project.create_story(name: story_name,
                                description: story_description,
                                estimate: 1,
                                labels: [buildpack_name, 'release'],
                                requested_by_id: tracker_requester_id
    )
  end

  def stories_since_last_release
    if most_recent_release_story
      buildpack_project.stories(with_label: buildpack_name,
                                after_story_id: most_recent_release_story.id
                               )
    else
      buildpack_project.stories(with_label: buildpack_name)
    end
  end

  def most_recent_release_story
    @latest_release_story ||= buildpack_project.stories(filter: "label:release AND label:#{buildpack_name}").last
  end
end
