#!/usr/bin/env ruby

stack = ENV.fetch('STACK')
ubuntu_version = ENV.fetch('UBUNTU_VERSION')
ubuntu_codename = ENV.fetch('UBUNTU_CODENAME')

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'rootfs'))
cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves', 'new-cve-notifications'))

require "#{buildpacks_ci_dir}/lib/rootfs-cve-notifier"

cve_notifier = RootFSCVENotifier.new(cves_dir, stacks_dir)

cve_notifier.run!(stack, ubuntu_version, ubuntu_codename, [])
