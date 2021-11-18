# encoding: utf-8
require 'tracker_api'

class BuildpackDeprecationStoryCreator
  attr_reader :buildpack_name, :manifest, :date, :tracker_requester_id, :buildpack_project, :before_story_id

  def initialize(buildpack_name:, manifest:, date:, tracker_project_id:, tracker_requester_id:, tracker_api_token:, before_story_id:)
    @buildpack_name = buildpack_name
    @manifest = manifest
    @date = date
    @tracker_requester_id = tracker_requester_id
    @before_story_id = before_story_id
    @buildpack_project = TrackerApi::Client.new(token: tracker_api_token).project(tracker_project_id)
  end

  def run
    deprecation_dates = find_dates(manifest, date)

    if deprecation_dates.size == 0
      puts 'No deprecated dependencies'
      exit 0
    end

    deprecation_dates.each do |d|
      version_line = d['version_line']
      story_name = "**Dependency Deprecation** #{buildpack_name}-buildpack: #{d['name']} #{version_line}"
      if story_exists(story_name)
        puts 'Deprecation Story already exists'
        next
      end

      story_description = "Deprecation Date: #{d['date']}\nLink: #{d['link']}"
      labels = ['deprecation', "#{buildpack_name}-buildpack", "#{d['name']}-dep"]

      story = buildpack_project.create_story(
          name: story_name,
          description: story_description,
          estimate: 1,
          labels: labels,
          requested_by_id: tracker_requester_id,
          before_id: before_story_id
      )
      story.save
    end
  end

  def story_exists(name)
    !!buildpack_project
            .stories(filter: "label:#{buildpack_name}-buildpack AND name:#{name}", limit: 1000).first
  end

end

def find_dates(manifest, today)
  if !manifest['dependency_deprecation_dates']
    return []
  end

  return manifest['dependency_deprecation_dates']
             .select {|d| d['date'] <= today + 30}
             .map {|d| d['date'] = d['date'].to_s; d}
end
