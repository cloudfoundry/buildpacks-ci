#!/usr/bin/env ruby
require_relative 'builder'
require_relative 'binary_builder_wrapper'
require_relative 'source_input'
require_relative 'build_input'
require_relative 'build_output'
require_relative 'artifact_output'
require_relative 'dep_metadata_output'

include Runner
include Sha
include Archive
include HTTPHelper

def main
  binary_builder  = BinaryBuilderWrapper.new(Runner)
  source_input    = SourceInput.from_file('source/data.json')
  stack           = ENV['STACK']
  skip_commit     = ENV['SKIP_COMMIT'] == 'true'
  build_input     = skip_commit ? BuildInput.new(nil, nil) : BuildInput.from_file("builds/binary-builds-new/#{source_input.name}/#{source_input.version}.json")
  build_output    = BuildOutput.new(source_input.name)
  artifact_output = ArtifactOutput.new(File.join(Dir.pwd, 'artifacts'))
  dep_metadata_output = DepMetadataOutput.new(File.join(Dir.pwd, 'dep-metadata'))
  out_data = Builder.new.execute(
    binary_builder,
    stack,
    source_input,
    build_input,
    build_output,
    artifact_output,
    dep_metadata_output,
    __dir__,
    skip_commit
  )
  p out_data
end

main
