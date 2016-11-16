#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'
require 'yaml'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/cf-release-common"

release_names.each do |language|
  blobs = YAML.load File.read('cf-release/config/blobs.yml')
  key = find_buildpack_key blobs, language
  src = Dir["#{language}-buildpack-github-release/*.zip"].first
  next unless src
  dst = File.join('cf-release', 'blobs', key)
  FileUtils.mkdir_p File.dirname(dst)
  FileUtils.mv src, dst
end

Dir.chdir 'cf-release' do
  system(%(bundle && bosh --parallel 10 sync blobs && bosh create release --force --with-tarball --name cf --version 212.0.#{Time.now.to_i})) || raise('cannot create cf-release')
end

system('rsync -a cf-release/ cf-release-artifacts') || raise('cannot rsync directories')
