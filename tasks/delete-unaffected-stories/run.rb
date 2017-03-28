#!/usr/bin/env ruby
require_relative './delete-unaffected-stories.rb'

DeleteUnaffectedStories.new(
  'tracker-filter-resource/data',
  'cflinuxfs2/cflinuxfs2/cflinuxfs2_receipt',
  'output/stories.json'
).run
