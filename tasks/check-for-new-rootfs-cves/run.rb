#!/usr/bin/env ruby

# Stack-agnostic CVE checker
# Required environment variables:
#   STACK - e.g., 'cflinuxfs4', 'cflinuxfs5'
#   UBUNTU_VERSION - e.g., 'Ubuntu 22.04', 'Ubuntu 24.04'
#   UBUNTU_CODENAME - e.g., 'ubuntu22.04', 'ubuntu24.04'

stack = ENV.fetch('STACK')
ubuntu_version = ENV.fetch('UBUNTU_VERSION')
ubuntu_codename = ENV.fetch('UBUNTU_CODENAME')

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'rootfs'))
cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'output-new-cves', 'new-cve-notifications'))

require "#{buildpacks_ci_dir}/lib/rootfs-cve-notifier"

cve_notifier = RootFSCVENotifier.new(cves_dir, stacks_dir)
cve_notifier.run!(stack, ubuntu_version, ubuntu_codename, [])
