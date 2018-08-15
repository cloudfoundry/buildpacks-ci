#!/usr/bin/env ruby

require 'open-uri'
require 'tracker_api'
require 'yaml'

class FinalizeSecurityNoticeStories
  def initialize(tracker_client, new_stack_version, stack)
    @tracker_client = tracker_client
    @new_stack_version = new_stack_version
    @stack = stack
  end

  def run
    fixed_affected_stories = @tracker_client.search_with_filters(label: ['affected', @stack], state: 'started')
    fixed_affected_stories.each do |story|
      puts "Changing label on #{story['id']} from affected to fixed-#{@new_stack_version}"
      @tracker_client.overwrite_label_on_story(story: story, existing_label_regex: /affected/, new_label: "fixed-#{@new_stack_version}")
      @tracker_client.change_story_state(story_id: story['id'], current_state: 'delivered')
    end
  end
end
