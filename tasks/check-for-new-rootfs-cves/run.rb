#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

require "#{buildpacks_ci_dir}/lib/buildpack-cve-tags"
require "#{buildpacks_ci_dir}/lib/buildpack-cve-notifier"
require "#{buildpacks_ci_dir}/lib/stack-cve-notifier"
require "#{buildpacks_ci_dir}/lib/cve-history"
require "#{buildpacks_ci_dir}/lib/notifiers/system-cve-tracker-notifier"
require "#{buildpacks_ci_dir}/lib/notifiers/system-cve-slack-notifier"
require "#{buildpacks_ci_dir}/lib/notifiers/system-cve-email-preparer-and-github-issue-notifier"

stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'stacks'))
cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves'))
cve_history = CVEHistory.new(cves_dir)

if ENV['STACK'] == 'stacks'
  notifiers = [SystemCVEEmailPreparerAndGithubIssueNotifier, SystemCVETrackerNotifier, SystemCVESlackNotifier]
elsif ENV['STACK'] == 'stacks-nc'
  notifiers = []
else
  raise "Unspported stack: #{ENV['STACK']}"
end

StackCVENotifier.new(cve_history, cves_dir, stacks_dir).run!('Ubuntu 14.04', 'ubuntu14.04', notifiers)

if ENV['STACK'] == 'stacks'
  languages = ['ruby']
  languages.each do |language|
    rss_cves = BuildpackCVETags.new(language).related_cves
    BuildpackCVENotifier.run(language, rss_cves)
  end
end
