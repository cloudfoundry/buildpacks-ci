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

    if buildpack != 'dotnet-core'
      metadata['release']['eccn'] = eccn
      metadata['release']['license_exception'] = license_exception
    end

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
  "#{formatted_name} #{get_version}"
end

def release_type
  "Minor Release"
end

def eula_slug
  "pivotal_software_eula"
end

def release_notes_url
  "https://github.com/cloudfoundry/#{buildpack}-buildpack/releases/tag/v#{get_version}"
end

def availability
  "All Users"
end

def eccn
  '5D002'
end

def license_exception
  'TSU'
end

def display_name
  "#{formatted_name} Buildpack (offline)"
end

def description
  File.read(recent_changes_filename)
end

def formatted_name
  if buildpack == "dotnet-core"
    ".NET Core"
  elsif buildpack == 'php'
    "PHP"
  elsif buildpack == 'nodejs'
    "NodeJS"
  else
    "#{buildpack.capitalize}"
  end
end
