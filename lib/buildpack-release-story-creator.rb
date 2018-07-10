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
    story_name = "**Release:** #{buildpack_name}-buildpack #{new_release_version}"

    story_description = stories_since_last_release.inject("Stories:\n\n") do |story_text, story|
      story_text += "##{story.id} - #{story.name}\n"
    end
    story_description += "\nRefer to [release instructions](https://docs.cloudfoundry.org/buildpacks/releasing_a_new_buildpack_version.html).\n"

    story = buildpack_project.create_story(
      name: story_name,
      description: story_description,
      estimate: 1,
      labels: [buildpack_name, 'release'],
      requested_by_id: tracker_requester_id
    )
    commit_msg = "git ci -m \"Bump version to $(cat VERSION) [##{story.id}]\""
    story.description = story_description + "\n**Commit Message**\n```\n#{commit_msg}\n```"
    story.save

    story
  end

  def stories_since_last_release
    story_id = most_recent_release_story_id
    all = buildpack_project.stories(filter: "label:#{buildpack_name} OR label:all", limit: 1000, auto_paginate: true)
    idx = all.find_index{ |s| s.id == story_id } if story_id
    idx ? all[(idx+1)..-1] : all
  end

  def most_recent_release_story_id
    story = buildpack_project.stories(filter: "label:release AND label:#{buildpack_name} AND -state:unscheduled").last
    story.id if story
  end

  def new_release_version
    @previous_buildpack_version.split('.').tap do |arr|
      arr[-1].succ!
    end.join('.')
  end
end
