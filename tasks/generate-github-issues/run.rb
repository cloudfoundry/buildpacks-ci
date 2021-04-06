#!/usr/bin/env ruby
#
require 'octokit'
require_relative '../../lib/github-issue-generator'

if ARGV.length != 4
  puts("Error: Arguments should be <title> <path/to/issue/description> <path/to/repo/list> <github_access_token>.")
  exit 1
end

issue_title = ARGV[0]
description_file_path = ARGV[1]
repos_list_file_path = ARGV[2]
github_token = ARGV[3]

client = Octokit::Client.new :access_token => github_token
GithubIssueGenerator.new(client).run(issue_title, description_file_path, repos_list_file_path)
