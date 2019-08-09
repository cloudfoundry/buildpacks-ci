#!/usr/bin/env ruby

require 'octokit'
require 'yaml'
require 'rubygems'
require 'zip'
require 'digest'
require 'fileutils'

repo = ENV.fetch('REPO')
stack = ENV.fetch('STACK', "cflinuxfs3")
GITHUB_ACCESS_TOKEN = ENV.fetch('GITHUB_ACCESS_TOKEN')

Octokit.configure do |c|
  c.access_token = GITHUB_ACCESS_TOKEN
end

def download_latest_release_if_exists(repo)
  repo_url = "cloudfoundry/#{repo}"
  unless Octokit.releases(repo_url)  == []
    latest_url = Octokit.latest_release(repo_url).zipball_url
    path = "source.zip"
    `wget -O #{path} #{latest_url}`
    path
  end
end

def open_manifest_from_zip(path)
  manifest = ""
  Zip::File.open(path) do |zip_file|
    entry = zip_file.glob('{*/,}manifest.yml').first
    if !entry.nil?
      manifest = YAML.load(entry.get_input_stream.read)
    end
  end
  manifest
end

def reduce_manifest(manifest)
  deps = manifest.fetch('dependencies').reduce({}) do |accumulator, dep|
    accumulator[dep['name']] = dep['version']
    accumulator
  end
  deps.reject!{|key| key == "lifecycle"}
end

def cnb_name(name)
  cnb_name = name.split('.').last
  if name.start_with? "org.cloudfoundry"
    "#{cnb_name}-cnb"
  elsif name.start_with? "io.pivotal"
    "p-#{cnb_name}-cnb"
  else
    raise "unknown cnb path"
  end
end

def get_url(name)
  if name.start_with? "org.cloudfoundry"
    "cloudfoundry/#{cnb_name(name)}"
  elsif name.start_with? "io.pivotal"
    "pivotal-cf/#{cnb_name(name)}"
  else
    raise "unknown cnb path"
  end
end

def find_version_diffs(old_deps, new_deps)
  cnb_version_map = {}
  new_deps.each do |dep, version|
    if old_deps.include? dep
      old_version = old_deps[dep]

      cnb_tags = Octokit.tags(get_url(dep)).collect{|tag| tag.name}
      # Get the releases in between the last and the current, inclusive of the current release
      diff_version = cnb_tags[cnb_tags.index("v#{version}"),cnb_tags.index("v#{old_version}") - 1]
      cnb_version_map[dep] = diff_version
    else
      cnb_version_map[dep] = ['new-cnb', "v#{version}"]
    end
  end

  cnb_version_map
end

def remove_tables(release_body)
  stripped_release_body = release_body.split('Packaged binaries:')[0]
  stripped_release_body.split('Supported stacks:')[0].strip!
end

def compile_release_notes(cnbs)
  release_notes = ""

  cnbs.each do |cnb, versions|
    release_notes << "\n# #{cnb_name(cnb)} \n"
    if versions.first == 'new-cnb'
      release_notes << "## Added version #{versions.last}\n"
    else
      releases = Octokit.releases(get_url(cnb)).select{|release| versions.include? release.name}
      releases.each_with_index do |release, index|
        trimmed_release_notes = (index > 0 ? remove_tables(release.body) : release.body.split("Supported stacks:")[0].strip!)
        release_notes << "## #{release.name}\n#{trimmed_release_notes}\n"
      end
    end
  end

  release_notes
end


old_manifest_deps = {}
latest_release_path = download_latest_release_if_exists(repo)
if File.exist? latest_release_path
  old_manifest = open_manifest_from_zip(latest_release_path)
  old_manifest_deps = reduce_manifest(old_manifest)
end

rc_path = Dir.glob(File.join("release-candidate", "*-v*.zip")).first
absolute_rc_path = File.absolute_path(rc_path)
current_manifest = open_manifest_from_zip(absolute_rc_path)
current_manifest_deps = reduce_manifest(current_manifest)

cnbs = find_version_diffs(old_manifest_deps, current_manifest_deps)

release_notes = compile_release_notes(cnbs)
puts release_notes
version = File.read(File.join("version", "version")).strip()
tag = "v#{version}"

rc_shasum = Digest::SHA256.file(absolute_rc_path).hexdigest

output_dir = File.absolute_path("buildpack-artifacts")
bp_name = "#{repo}-#{stack}-#{tag}.zip"
sha_file_name = "#{bp_name}.SHA256SUM.txt"
File.write(File.join(output_dir, "tag"), tag)
File.write(File.join(output_dir, "release_notes"), release_notes)
FileUtils.mv(absolute_rc_path, File.join(output_dir, bp_name))
File.write(File.join(output_dir, sha_file_name), rc_shasum)
