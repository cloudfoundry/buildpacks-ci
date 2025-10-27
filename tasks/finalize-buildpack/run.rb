#!/usr/bin/env ruby

require_relative 'buildpack-finalizer'

artifact_dir = File.join(Dir.pwd, 'buildpack-artifacts')
version = if File.exist?('version/number')
            File.read('version/number').strip
          else
            File.read('buildpack/VERSION').strip
          end

buildpack_repo_dir = 'buildpack'
uncached_buildpack_dirs = Dir.glob('uncached-buildpack-for-stack*')

ENV['GOBIN'] = "#{File.expand_path(buildpack_repo_dir)}/.bin"
ENV['PATH'] = "#{ENV.fetch('GOBIN', nil)}:#{ENV.fetch('PATH', nil)}"

BuildpackFinalizer.new(artifact_dir, version, buildpack_repo_dir, uncached_buildpack_dirs).run
