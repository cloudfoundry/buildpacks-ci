#!/usr/bin/env ruby

if ENV['ROOTFS_TYPE'] == 'nc'
  repo = 'pivotal-cf/stacks-nc'
else
  repo = 'cloudfoundry/stacks'
end

body_file = 'release-body/body'
version = `cat version/number`
github_url = "https://github.com/#{repo}/releases/tag/#{version}"

message = "This release ships with #{repo.split('/').last} version #{version}. For more information, see this stack's [release notes](#{github_url})"

File.write(body_file, message)
