#!/usr/bin/env ruby

require 'yaml'

class BuildpackPivnetMetadataWriter

  attr_reader :buildpack, :output_dir, :buildpack_dir, :cached_buildpack_filename, :recent_changes_filename

  def initialize(buildpack, output_dir, buildpack_dir, cached_buildpack_filename, recent_changes_filename)
    @buildpack = buildpack
    @output_dir = output_dir
    @buildpack_dir = buildpack_dir
    @cached_buildpack_filename = cached_buildpack_filename
    @recent_changes_filename = recent_changes_filename
  end

  def get_version
    Dir.chdir(buildpack_dir) do
      File.read('VERSION').strip
    end
  end

  def run!
    metadata_yml = File.join(output_dir, "#{buildpack}.yml")

    metadata = {}
    metadata['release'] = {
      'version' => product_version,
      'release_type' => release_type,
      'eula_slug' => eula_slug,
      'release_notes_url' => release_notes_url,
      'availability' => availability
    }
    metadata['product_files'] = [ {
      'file' => File.join('pivotal-buildpack-cached', cached_buildpack_filename),
      'upload_as' => display_name,
      'description' => description
    } ]

    puts "Writing metadata to #{metadata_yml}"
    puts metadata.to_yaml
    puts "\n\n"

    File.write(metadata_yml, metadata.to_yaml)
  end
end

private

def product_version
  if buildpack == 'dotnet-core'
    ".NET Core #{get_version} (BETA)"
  elsif buildpack == 'php'
    "PHP #{get_version}"
  elsif buildpack == 'nodejs'
    "NodeJS #{get_version}"
  else
    "#{buildpack.capitalize} #{get_version}"
  end
end

def release_type
  if buildpack == 'dotnet-core'
    "Beta Release"
  else
    "Minor Release"
  end
end

def eula_slug
  if buildpack == "dotnet-core"
    "pivotal_beta_eula"
  else
    "pivotal_software_eula"
  end
end

def release_notes_url
  if buildpack == "dotnet-core"
    "https://github.com/cloudfoundry-incubator/dotnet-core-buildpack/releases/tag/v#{get_version}"
  else
    "https://github.com/cloudfoundry/#{buildpack}-buildpack/releases/tag/v#{get_version}"
  end
end

def availability
  if buildpack == "dotnet-core"
    "Admins Only"
  else
    "All Users"
  end
end

def display_name
  if buildpack == "dotnet-core"
    ".NET Core Buildpack BETA (offline)"
  elsif buildpack == 'php'
    "PHP Buildpack (offline)"
  elsif buildpack == 'nodejs'
    "NodeJS Buildpack (offline)"
  else
    "#{buildpack.capitalize} Buildpack (offline)"
  end
end

def description
  File.read(recent_changes_filename)
end
