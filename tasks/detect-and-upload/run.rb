#!/usr/bin/env ruby

require_relative 'buildpack-tagger'

Dir.chdir('..') do
  buildpack_dir = File.join(Dir.pwd, 'buildpack')
  buildpack_name = ENV['BUILDPACK_NAME']
  git_repo_org = ENV['GIT_REPO_ORG']

  tagger = BuildpackTagger.new(buildpack_dir, buildpack_name, git_repo_org)
  tagger.run!
end
