#!/usr/bin/env ruby
# encoding: utf-8

require_relative 's3-dependency-uploader'

S3DependencyUploader.new(ENV['DEPENDENCY'], ENV['BUCKET_NAME'], 'binary-builder-artifacts').run
