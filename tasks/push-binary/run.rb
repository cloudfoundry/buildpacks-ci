#!/usr/bin/env ruby
# encoding: utf-8

require_relative 's3-dependency-uploader'

S3DependencyUploader.new(ENV.fetch('DEPENDENCY'), ENV.fetch('BUCKET_NAME'), 'binary-builder-artifacts').run
