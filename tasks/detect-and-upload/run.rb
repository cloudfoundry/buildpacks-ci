#!/usr/bin/env ruby

require_relative 'buildpack-tagger'

buildpack_dir = File.join(Dir.pwd, 'buildpack')

tagger = BuildpackTagger.new(buildpack_dir)
tagger.run!

