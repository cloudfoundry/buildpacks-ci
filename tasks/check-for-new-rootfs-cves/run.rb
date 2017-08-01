#!/usr/bin/env ruby
# encoding: utf-8

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

require "#{buildpacks_ci_dir}/lib/rootfs-cve-notifier"
require "#{buildpacks_ci_dir}/lib/notifiers/cve-tracker-notifier"
require "#{buildpacks_ci_dir}/lib/notifiers/cve-slack-notifier"
require "#{buildpacks_ci_dir}/lib/notifiers/cve-email-preparer-and-github-issue-notifier"

stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'cflinuxfs2'))

if ENV.fetch('STACK') == 'cflinuxfs2'
  notifiers = [CVEEmailPreparerAndGithubIssueNotifier, CVESlackNotifier, CVETrackerNotifier]
  cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves', 'new-cve-notifications'))
else
  raise "Unsupported stack: #{ENV.fetch('STACK')}"
end

RootFSCVENotifier.new(cves_dir, stacks_dir).run!('Ubuntu 14.04', 'ubuntu14.04', notifiers)
