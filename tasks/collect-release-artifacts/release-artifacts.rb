#!/usr/bin/env ruby

require 'octokit'
require 'yaml'
require 'rubygems'
require 'zip'
require 'digest'
require 'fileutils'
require 'erb'
require 'toml'
require 'zlib'
require 'rubygems/package'
require 'tomlrb'

require_relative './cnb'

class ReleaseArtifacts
  class << self
    def download_latest_release(repo, octokit = Octokit)
      repo_url = "cloudfoundry/#{repo}"
      unless octokit.releases(repo_url) == []
        latest_url = octokit.latest_release(repo_url).zipball_url
        path       = "source.zip"
        `wget -O #{path} #{latest_url}`
        path
      end
    end

    def open_buildpacktoml_from_tgz(path)
      Gem::Package::TarReader.new( Zlib::GzipReader.open path ) do |tar|
        tar.each do |entry|
          if entry.full_name == 'buildpack.toml'
           return Tomlrb.parse(entry.read.strip)
          end
        end
      end
      {}
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

    def find_version_diff(old_deps, new_deps, octokit = Octokit)
      cnb_version_map = {}
      new_deps.each do |id, current_version|
        if old_deps.include? id
          old_version = old_deps[id]
          _, url      = CNB.name_and_url(id)
          cnb_tags    = octokit.tags(url).collect { |tag| tag.name }
          # Get the releases in between the last and the current, inclusive of the current release
          cnb_version_map[id] = cnb_tags[cnb_tags.index("v#{current_version}")...cnb_tags.index("v#{old_version}")]
        else
          cnb_version_map[id] = ['new-cnb', "v#{current_version}"]
        end
      end
      cnb_version_map
    end

# Seemingly unnecessary parameters are important for the binding object used with ERB
    def compile_release_notes(shim, tag, cnb_version_diff, oktokit = Octokit)
      template = ERB.new(File.read(File.join(File.dirname(__FILE__), "release-notes.md.erb")))
      cnbs = cnb_version_diff.map do |id, versions|
        CNB.new(id, versions, oktokit)
      end

      b = binding
      template.result(b)
    end

  end
end
