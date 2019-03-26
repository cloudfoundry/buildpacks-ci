#!/usr/bin/env ruby

require 'tomlrb' # One gem to read (supports v0.4.0)
require 'toml' #One to write

version = File.read(File.join("version", "version")).strip()
builder_image = ENV.fetch("BUILDER_IMAGE")
build_image = ENV.fetch("BUILD_IMAGE")
run_image = ENV.fetch("RUN_IMAGE")
stack = ENV.fetch("STACK")
builder_config_file = "builder.toml"

Dir.chdir "pack" do
  system "go", "build", "./cmd/pack" or exit 1
end

buildpacks = Dir.glob("cnb-repo*/").map do |dir|
  id = Tomlrb.load_file(File.join(dir, "buildpack.toml"))['buildpack']['id']
  bp_file = ""
  Dir.chdir dir do
    if Dir.exist?("ci") # TODO: This exists because we package Buildpacks differently
      system File.join("ci", "package.sh") or exit 1
      bp_file = File.join(dir, Dir.glob(File.join("artifactory", "*", "*", "*", "*", "*", "*.tgz")).first)
    else
      system File.join("scripts", "package.sh") or exit 1
      bp_file = File.join(dir, Dir.glob("*.tgz").first)
    end
  end
  {
      "id": id,
      "uri": bp_file
  }
end

groups = Tomlrb.load_file(File.join("buildpacks-ci", "tasks", "create-builder", "order.toml"))['groups']

config_hash = {
    "buildpacks": buildpacks,
    "groups": groups,
    "stack": {
        "id": stack,
        "build-image": build_image,
        "run-image": run_image
    }
}

builder_config = TOML::Generator.new(config_hash).body
File.write(builder_config_file, builder_config)

system "buildpacks-ci/scripts/start-docker" or exit 1
system "./pack/pack", "create-builder", "#{builder_image}:#{version}", "--builder-config", "#{builder_config_file}" or exit 1
system "docker", "save", "#{builder_image}", "-o", "builder-image/builder.tgz" or exit 1
