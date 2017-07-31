#!/usr/bin/env ruby
# encoding: utf-8

require 'fileutils'
require 'yaml'

Dir.chdir 'diego-release' do
  system(%(bosh --parallel 10 sync blobs && bosh create release --force --with-tarball --name diego --version 0.#{Time.now.to_i})) || raise('cannot create diego-release')
end

system('rsync -a diego-release/ diego-release-artifacts') || raise('cannot rsync directories')
