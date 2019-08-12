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

def download_latest_release(repo)
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
    unless entry.nil?
      manifest = YAML.load(entry.get_input_stream.read)
    end
  end
  manifest
end

def reduce_manifest(manifest)
  manifest.fetch('dependencies').reduce({}) do |accumulator, dep|
    accumulator[dep['name']] = dep['version']
    accumulator
  end
end

def cnb_name_and_url(name)
  cnb_name = name.split('.').last
  url = ""
  if name.start_with? "org.cloudfoundry"
    name = "#{cnb_name}-cnb"
    url = "cloudfoundry/#{name}"
  elsif name.start_with? "io.pivotal"
    name = "p-#{cnb_name}-cnb"
    url "pivotal-cf/#{name}"
  elsif name.start_with? "lifecycle"
    url = "buildpack/#{name}"
  else
    raise "unknown cnb path"
  end
  [name, url]
end

def find_version_diffs(old_deps, new_deps)
  cnb_version_map = {}
  new_deps.each do |dep, version|
    if old_deps.include? dep
      old_version = old_deps[dep]
      _, url = cnb_name_and_url(dep)
      cnb_tags = Octokit.tags(url).collect{|tag| tag.name}
      # Get the releases in between the last and the current, inclusive of the current release
      diff_version = cnb_tags[cnb_tags.index("v#{version}"),cnb_tags.index("v#{old_version}")]
      cnb_version_map[dep] = diff_version
    else
      cnb_version_map[dep] = ['new-cnb', "v#{version}"]
    end
  end
  cnb_version_map
end

def clean_release_notes(release_body)
  if release_body.include? "No major changes"
    return ""
  end
  stripped_release_body = release_body.split('Packaged binaries:')[0]
  stripped_release_body.split('Supported stacks:')[0].strip!
end

def binaries_and_stacks_for_cnb(release)
  idx = release.index("Packaged binaries") || 0
  if idx == 0
    idx = release.index("Supported stacks") || release.length
  end
  # Returns substring from that index until the end
  release[idx..-1]
end

def compile_release_notes(repo, cnbs)
  intro_release_notes = "# #{repo.upcase} \nBelow are the release notes for:\n"
  cnbs_release_notes = ""
  cnbs.each do |cnb, versions|
    name, url = cnb_name_and_url(cnb)
    intro_release_notes << "\n* #{name} "
    cnbs_release_notes << "\n## #{name} \n"
    if versions.first == 'new-cnb'
      cnbs_release_notes << "### Added version #{versions.last}\n"
    else
      releases = Octokit.releases(url).select{|release| versions.include? release.tag_name}
      releases.each_with_index do |release, index|
        if index == 0
          # Add binaries and stack information before any version specific release notes
          cnbs_release_notes << "#{binaries_and_stacks_for_cnb(release.body)}\n"
        end
        trimmed_release_notes = clean_release_notes(release.body)
        more_details = "More details are [here](#{release.html_url})."
        cnbs_release_notes << "### #{release.name}\n#{trimmed_release_notes}\n\n#{more_details}\n"
      end
    end
  end

  intro_release_notes + cnbs_release_notes
end


old_manifest_deps = {}
latest_release_path = download_latest_release(repo)
if File.exist? latest_release_path
  old_manifest = open_manifest_from_zip(latest_release_path)
  old_manifest_deps = reduce_manifest(old_manifest)
end

rc_path = Dir.glob(File.join("release-candidate", "*-v*.zip")).first
absolute_rc_path = File.absolute_path(rc_path)
current_manifest = open_manifest_from_zip(absolute_rc_path)
current_manifest_deps = reduce_manifest(current_manifest)

cnbs = find_version_diffs(old_manifest_deps, current_manifest_deps)

release_notes = compile_release_notes(repo, cnbs)
puts release_notes
version = File.read(File.join("version", "version")).strip()
tag = "v#{version}"

rc_shasum = Digest::SHA256.file(absolute_rc_path).hexdigest

output_dir = File.absolute_path("buildpack-artifacts")
bp_name = "#{repo}-compat-#{stack}-#{tag}.zip"
sha_file_name = "#{bp_name}.SHA256SUM.txt"
File.write(File.join(output_dir, "tag"), tag)
File.write(File.join(output_dir, "release_notes"), release_notes)
FileUtils.mv(absolute_rc_path, File.join(output_dir, bp_name))
File.write(File.join(output_dir, sha_file_name), rc_shasum)
