#!/usr/bin/env ruby
# encoding: utf-8

require_relative 'aspnetcore_extractor'
require_relative '../build-binary-new/source_input'
require_relative '../build-binary-new/build_input'
require_relative '../build-binary-new/build_output'
require_relative '../build-binary-new/artifact_output'

stack           = ENV['STACK']
source_input    = SourceInput.from_file 'source/data.json'
build_input     = BuildInput.from_file "builds/binary-builds-new/dotnet-sdk/#{source_input.version}-#{stack}.json"
build_output    = BuildOutput.new('dotnet-aspnetcore')
artifact_output = ArtifactOutput.new('binary-builder-artifacts')

out_data = AspnetcoreExtractor.new(
  stack,
  build_input,
  build_output,
  artifact_output
).run

p out_data