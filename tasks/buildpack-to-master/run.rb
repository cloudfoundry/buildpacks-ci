#!/usr/bin/env ruby
require_relative './buildpack-to-master.rb'

GITHUB_ACCESS_TOKEN = ENV.fetch('GITHUB_ACCESS_TOKEN') or raise 'Must supply env GITHUB_ACCESS_TOKEN'
GITHUB_REPO = ENV.fetch('GITHUB_REPO') or raise 'Must supply env GITHUB_REPO'
GITHUB_STATUS_CONTEXT = ENV.fetch('GITHUB_STATUS_CONTEXT') or raise 'Must supply env GITHUB_STATUS_CONTEXT'
PIPELINE_URI = ENV.fetch('PIPELINE_URI') or raise 'Must supply env PIPELINE_URI'

## Optional (with default)
GITHUB_STATUS_DESCRIPTION = ENV.fetch('GITHUB_STATUS_DESCRIPTION', 'Buildpacks CI build success')

BuildpackToMaster.new(GITHUB_ACCESS_TOKEN, GITHUB_REPO, GITHUB_STATUS_CONTEXT, GITHUB_STATUS_DESCRIPTION, PIPELINE_URI).run
