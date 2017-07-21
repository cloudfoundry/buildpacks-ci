#!/usr/bin/env ruby
require 'octokit'

## Required
LOCAL_REPO_DIR = ENV.fetch('LOCAL_REPO_DIR') or raise 'Must supply env LOCAL_REPO_DIR'
GITHUB_ACCESS_TOKEN = ENV.fetch('GITHUB_ACCESS_TOKEN') or raise 'Must supply env GITHUB_ACCESS_TOKEN'
GITHUB_REPO = ENV.fetch('GITHUB_REPO') or raise 'Must supply env GITHUB_REPO'
GITHUB_STATUS_CONTEXT = ENV.fetch('GITHUB_STATUS_CONTEXT') or raise 'Must supply env GITHUB_STATUS_CONTEXT'
PIPELINE_URI = ENV.fetch('PIPELINE_URI') or raise 'Must supply env PIPELINE_URI'

## Optional (with default)
GITHUB_STATUS_DESCRIPTION = ENV.fetch('GITHUB_STATUS_DESCRIPTION', 'Buildpacks CI build success')

Octokit.configure do |c|
  c.access_token = GITHUB_ACCESS_TOKEN
end

sha = Dir.chdir(LOCAL_REPO_DIR) do
  `git rev-parse HEAD`.chomp
end

Octokit.create_status(
  GITHUB_REPO,
  sha,
  'success',
  context: GITHUB_STATUS_CONTEXT,
  description: GITHUB_STATUS_DESCRIPTION,
  target_url: PIPELINE_URI
)

