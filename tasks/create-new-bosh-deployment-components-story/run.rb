#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'bosh-component-story-creator'

Dir.chdir('..') do
  BoshComponentStoryCreator.new.run!

  system "rsync -a public-buildpacks-ci-robots/ buildpacks-robots-artifacts"
end



