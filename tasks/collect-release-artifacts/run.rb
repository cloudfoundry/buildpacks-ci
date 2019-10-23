#!/usr/bin/env ruby

require 'octokit'
require 'yaml'
require 'rubygems'
require 'zip'
require 'digest'
require 'fileutils'
require_relative './release-artifacts'
require 'toml'

repo = ENV.fetch('REPO', '')
stack = ENV.fetch('STACK', "cflinuxfs3")
GITHUB_ACCESS_TOKEN = ENV.fetch('GITHUB_ACCESS_TOKEN', '')

Octokit.configure do |c|
  c.access_token = GITHUB_ACCESS_TOKEN
end

# old_manifest_deps = {}
# latest_release_path = ReleaseArtifacts.download_latest_release(repo)
# if File.exist? latest_release_path
#   old_manifest = ReleaseArtifacts.open_manifest_from_zip(latest_release_path)
#   old_manifest_deps = ReleaseArtifacts.reduce_manifest(old_manifest)
# end

# below path is needed for the shimmed buildpack
# rc_path = Dir.glob(File.join("cnb-release-candidate", "*-v*.zip")).first
rc_path = Dir.glob(File.join("cnb-release-candidate", "*-v*.tgz")).first
absolute_rc_path = File.absolute_path(rc_path)
puts absolute_rc_path

# current_manifest = ReleaseArtifacts.open_manifest_from_zip(absolute_rc_path)
# current_manifest_deps = ReleaseArtifacts.reduce_manifest(current_manifest)
#
# cnb_version_diff = ReleaseArtifacts.find_version_diff(old_manifest_deps, current_manifest_deps)

version = File.read(File.join("version", "version")).strip()
tag = "v#{version}"
# release_notes = ReleaseArtifacts.compile_release_notes(repo, tag, cnb_version_diff)

# extract buildpack.toml
bp_toml = ReleaseArtifacts.open_buildpacktoml_from_tgz(absolute_rc_path)

bp_toml_string = TOML::Generator.new(bp_toml).body
File.open("buildpack.toml", "w") do |file|
  file << bp_toml_string
end

puts `buildpack/scripts/install_tools.sh`

packager_path = "buildpack/.bin/packager"
release_notes = `#{packager_path} -summary`
puts release_notes

rc_shasum = Digest::SHA256.file(absolute_rc_path).hexdigest

output_dir = File.absolute_path("buildpack-artifacts")
cnb_name = "#{repo}-#{tag}.tgz"
bp_name = File.basename(absolute_rc_path)
sha_file_name = "#{bp_name}.SHA256SUM.txt"
File.write(File.join(output_dir, "tag"), tag)
File.write(File.join(output_dir, "release_notes"), release_notes)
FileUtils.mv(absolute_rc_path, File.join(output_dir, cnb_name))
File.write(File.join(output_dir, sha_file_name), rc_shasum)
