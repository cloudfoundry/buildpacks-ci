#!/usr/bin/env ruby
require 'octokit'

Octokit.configure do |c|
  c.access_token = ENV['GITHUB_ACCESS_TOKEN']
end

sha = `git rev-parse HEAD`.chomp
Octokit.create_status(
    'cloudfoundry/buildpacks-ci',
    sha,
    'success',
    context: "buildpacks-ci/merge-to-master",
    description: "Buildpacks CI build success",
    target_url: ENV['PIPELINE_URI']
)

