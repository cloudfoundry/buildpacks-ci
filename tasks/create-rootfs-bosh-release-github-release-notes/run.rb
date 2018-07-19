#!/usr/bin/env ruby

stack = ENV['STACK']
repo = "cloudfoundry/#{stack}"

body_file = 'release-body/body'
version = `cat version/number`
github_url = "https://github.com/#{repo}/releases/tag/#{version}"

message = "This release ships with #{stack} version #{version}. For more information, see the [release notes](#{github_url})"

File.write(body_file, message)
