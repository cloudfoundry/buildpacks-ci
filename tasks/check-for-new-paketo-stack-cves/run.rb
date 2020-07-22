#!/usr/bin/env ruby
# encoding: utf-8

stack = ENV['STACK']
image = ENV['IMAGE']

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'stack-receipt'))
cves_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'new-cves', 'new-paketo-stack-cve-notifications', stack, image))

require "#{buildpacks_ci_dir}/lib/rootfs-cve-notifier"

RootFSCVENotifier.new(cves_dir, stacks_dir).run!(stack, 'Ubuntu 18.04', 'ubuntu18.04', [])
