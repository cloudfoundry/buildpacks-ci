#!/usr/bin/env ruby
# encoding: utf-8

stack = ENV['STACK']

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', stack.gsub(/m$/, '')))
if stack == 'tiny'
  stacks_dir = File.expand_path(File.join(buildpacks_ci_dir,  '..', 'tiny', 'tiny', 'base', 'run'))
end
cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves', 'new-cve-notifications'))

require "#{buildpacks_ci_dir}/lib/rootfs-cve-notifier"
require "#{buildpacks_ci_dir}/lib/notifiers/cve-slack-notifier"

notifiers = [CVESlackNotifier]
cve_notifier = RootFSCVENotifier.new(cves_dir, stacks_dir)

case stack
when 'cflinuxfs2'
  cve_notifier.run!(stack, 'Ubuntu 14.04', 'ubuntu14.04', [])
when 'cflinuxfs3'
  cve_notifier.run!(stack, 'Ubuntu 18.04', 'ubuntu18.04', notifiers)
when 'tiny'
  cve_notifier.run!(stack, 'Ubuntu 18.04', 'ubuntu18.04-tiny', [])
else
  raise "Unsupported stack: #{stack}"
end
