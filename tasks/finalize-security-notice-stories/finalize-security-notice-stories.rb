#!/usr/bin/env ruby

require 'open-uri'
require 'tracker_api'
require 'yaml'

class FinalizeSecurityNoticeStories
  def initialize(tracker_client, new_stack_version)
    @tracker_client = tracker_client
    @new_stack_version = new_stack_version
  end

  def run
    fixed_affected_stories = @tracker_client.search_with_filters(label: 'affected-*', state: 'started')
    fixed_affected_stories.each do |story|
      @tracker_client.add_label_to_story(story: story, label: "fixed-#{@new_stack_version}")
      @tracker_client.change_story_state(story_id: story["id"], current_state: 'delivered')
    end
  end
end
