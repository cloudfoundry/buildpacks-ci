#!/usr/bin/env ruby
require_relative 'builder'
require_relative 'binary_builder_wrapper'
require_relative 'source_input'
require_relative 'build_input'
require_relative 'build_output'
require_relative 'artifact_output'

include Runner
include Sha
include DependencyBuild

def main
  binary_builder  = BinaryBuilderWrapper.new(Runner)
  source_input    = SourceInput.from_file('source/data.json')
  build_input     = BuildInput.from_file("builds/binary-builds-new/#{source_input.name}/#{source_input.version}.json")
  build_output    = BuildOutput.new(source_input.name)
  artifact_output = ArtifactOutput.new(File.join(Dir.pwd, 'artifacts'))
  out_data = Builder.new.execute(
    binary_builder,
    ENV['STACK'],
    source_input,
    build_input,
    build_output,
    artifact_output
  )
  p out_data
end

main
