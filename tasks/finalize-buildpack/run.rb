#!/usr/bin/env ruby
# encoding: utf-8
require_relative 'buildpack-finalizer'

artifact_dir = File.join(Dir.pwd, 'buildpack-artifacts')
version = File.read('buildpack/VERSION').strip

buildpack_repo_dir = 'buildpack'
uncached_buildpack_dir = 'pivotal-buildpacks'

ENV['GOPATH']=File.expand_path(buildpack_repo_dir)
ENV['GOBIN']="#{ENV['GOPATH']}/.bin"
ENV['PATH']="#{ENV['GOBIN']}:#{ENV['PATH']}"

BuildpackFinalizer.new(artifact_dir, version, buildpack_repo_dir, uncached_buildpack_dir).run
