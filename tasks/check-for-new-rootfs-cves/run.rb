#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

require "#{buildpacks_ci_dir}/lib/stack-cve-notifier"
require "#{buildpacks_ci_dir}/lib/cve-history"
require "#{buildpacks_ci_dir}/lib/notifiers/system-cve-tracker-notifier"
require "#{buildpacks_ci_dir}/lib/notifiers/system-cve-slack-notifier"
require "#{buildpacks_ci_dir}/lib/notifiers/system-cve-email-preparer-and-github-issue-notifier"

stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'stacks'))

if ENV.fetch('STACK') == 'stacks'
  notifiers = [SystemCVEEmailPreparerAndGithubIssueNotifier, SystemCVETrackerNotifier, SystemCVESlackNotifier]
  cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves', 'new-cve-notifications'))
elsif ENV.fetch('STACK') == 'stacks-nc'
  notifiers = []
  cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves', 'new-cves-stacks-nc'))
else
  raise "Unsupported stack: #{ENV.fetch('STACK')}"
end

cve_history = CVEHistory.new(cves_dir)

StackCVENotifier.new(cve_history, cves_dir, stacks_dir).run!('Ubuntu 14.04', 'ubuntu14.04', notifiers)
