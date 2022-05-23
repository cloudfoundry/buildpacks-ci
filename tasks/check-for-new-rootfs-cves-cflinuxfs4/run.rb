#!/usr/bin/env ruby
# encoding: utf-8

stack = 'cflinuxfs4'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', stack.gsub(/m$/, '')))
cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves', 'new-cve-notifications'))

require "#{buildpacks_ci_dir}/lib/rootfs-cve-notifier"

cve_notifier = RootFSCVENotifier.new(cves_dir, stacks_dir)

cve_notifier.run!(stack, 'Ubuntu 22.04', 'ubuntu22.04', [])
