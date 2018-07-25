#!/usr/bin/env ruby

require 'open-uri'
require 'tracker_api'
require 'pry'
require 'yaml'

class CategorizeSecurityNotices
  attr_reader :stories

  def initialize(tracker_client, stories_file, stack_receipt, davos_client, stack)
    ref = JSON.parse(File.read(stories_file))
    @tracker_client = tracker_client
    @stories = JSON.parse(ref['version']['ref'])
    @receipt = File.read(stack_receipt)
    @davos_client = davos_client
    @stack = stack
  end

  def run
    stories.each do |story|
      next unless story['labels'].include? @stack
      packages = get_story_packages(story)
      if affected?(packages)
        label_story(story, "affected")
        zero_point_story(story['id'])
        start_story(story['id'])
        davos_change(story, status: 'acknowledged')
      else
        label_story(story, "unaffected")
        zero_point_story(story['id'])
        deliver_story(story['id'])
        davos_change(story, status: 'unaffected')
      end
    end
  end

  private

  def get_story_packages(story)
    exp =
        case @stack
        when 'cflinuxfs2'
          Regexp.new('\*\*Trusty Packages:\*\*\n(.*?)\n\n', Regexp::MULTILINE)
        when 'cflinuxfs3'
          Regexp.new('\*\*Bionic Packages:\*\*\n(.*?)\n\n', Regexp::MULTILINE)
        else
          raise "Unsupported stack: #{stack}"
        end

    package_list = exp.match(story['description'])[1].split("\n")
    package_list.map { |package| package.lstrip }
  end

  def affected?(packages)
    packages.each do |package|
      package_name = package.split(" ").first
      exp = Regexp.new("^\\w+\\s+" + Regexp.escape(package_name) + ":?\\S*\\s+")
      return true if exp.match(@receipt)
    end

    false
  end

  def label_story(story, label)
    @tracker_client.add_label_to_story(story: story, label: label)
  end

  def zero_point_story(story_id)
    @tracker_client.point_story(story_id: story_id, estimate: 0)
  end

  def deliver_story(story_id)
    @tracker_client.change_story_state(story_id: story_id, current_state: "delivered")
  end

  def start_story(story_id)
    @tracker_client.change_story_state(story_id: story_id, current_state: "started")
  end

  def davos_change(story, params)
    m = story['description'].match(%r{\(https://davos.cfapps.io/product_stories/(\d+)\)})
    return unless m&.length == 2
    @davos_client.change(m[1], params)
  end
end
