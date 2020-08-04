#!/usr/bin/env ruby
# encoding: utf-8

stack = ENV['STACK']
image = ENV['IMAGE']

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
stacks_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'stack-image-receipt'))
usns_dir = File.expand_path(File.join(buildpacks_ci_dir, '..', 'new-usns', 'new-paketo-stack-usns', stack, image))

require "#{buildpacks_ci_dir}/lib/rootfs-cve-notifier"

RootFSCVENotifier.new(usns_dir, stacks_dir).run!(stack, 'Ubuntu 18.04', 'ubuntu18.04', [])
