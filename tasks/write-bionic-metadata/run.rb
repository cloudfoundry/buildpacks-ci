#!/usr/bin/env ruby
require 'open-uri'
require 'digest'
require_relative '../build-binary-new/source_input'
require_relative '../build-binary-new/build_input'
require_relative '../build-binary-new/build_output'

def get_sha_from_text_file(url)
  open(url).read.match(/^(.*) .*linux-x64.tar.gz$/).captures.first.strip
end

source_input    = SourceInput.from_file('source/data.json')
build_input     = BuildInput.from_file("builds/binary-builds-new/#{source_input.name}/#{source_input.version}.json")
build_output    = BuildOutput.new(source_input.name)
stack = ENV.fetch("STACK")
stack_id = ENV.fetch("STACK_ID")

build_input.copy_to_build_output


def get_sha_from_file(file)
  Digest::SHA256.file file
end

case source_input.name
when 'go'
  path = "go#{source_input.version}.linux-amd64.tar.gz"
  url = "https://dl.google.com/go/#{path}"
  `wget #{url}`
  build_output.add_output("#{source_input.version}-#{stack}.json",
    {
      sha256: get_sha_from_file(path),
      url: url
    }
  )

when 'node'
  build_output.add_output("#{source_input.version}-#{stack}.json",
    {
      sha256: get_sha_from_text_file("https://nodejs.org/dist/v#{source_input.version}/SHASUMS256.txt"),
      url: "https://nodejs.org/dist/v#{source_input.version}/node-v#{source_input.version}-linux-x64.tar.gz"
    }
  )
end


build_output.commit_outputs("Build #{source_input.name} - #{source_input.version} - #{stack_id} [##{build_input.tracker_story_id}]")
