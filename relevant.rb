#!/usr/bin/env ruby
require 'rubygems'
require 'excon'
require 'json'

conf = JSON.parse(STDIN.read)

LABEL = conf.dig('source', 'label')
PROJECT_ID = conf.dig('source', 'project_id')
TOKEN = conf.dig('source', 'token')
tracker = Excon.new("https://www.pivotaltracker.com/", headers: {'X-TrackerToken'=>TOKEN})

resp = tracker.get(path: "/services/v5/projects/#{PROJECT_ID}/search", query: "query=label%3A#{LABEL}")

data = JSON.parse(resp.body)

data.dig('stories', 'stories').each do |story|
  story = JSON.parse(tracker.get(path: "/services/v5/projects/#{PROJECT_ID}/stories/#{story['id']}").body)
  p story
end
