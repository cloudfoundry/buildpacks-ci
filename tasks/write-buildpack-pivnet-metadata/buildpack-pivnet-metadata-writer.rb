#!/usr/bin/env ruby

require 'yaml'

class BuildpackPivnetMetadataWriter

  attr_reader :buildpack, :output_dir, :buildpack_dir, :cached_buildpack_filenames, :recent_changes_filename

  def initialize(buildpack, output_dir, buildpack_dir, cached_buildpack_filenames, recent_changes_filename, lts_product)
    @buildpack = buildpack
    @output_dir = output_dir
    @buildpack_dir = buildpack_dir
    @cached_buildpack_filenames = cached_buildpack_filenames
    @recent_changes_filename = recent_changes_filename
    @lts_product = lts_product
  end

  def get_version
    Dir.chdir(buildpack_dir) do
      File.read('VERSION').strip
    end
  end

  def run!
    metadata_file_name = @lts_product == "true" ? "#{buildpack}-lts.yml" : "#{buildpack}.yml"
    metadata_yml = File.join(output_dir, metadata_file_name)
    version = @lts_product == "true" ? product_version : get_version

    metadata = {}
    metadata['release'] = {
        'version' => version,
        'release_type' => release_type,
        'eula_slug' => eula_slug,
        'release_notes_url' => release_notes_url,
        'availability' => availability
    }

    if buildpack != 'dotnet-core'
      metadata['release']['eccn'] = eccn
      metadata['release']['license_exception'] = license_exception
    end

    metadata['product_files'] = []
    cached_buildpack_filenames.each do |filename|
      stack = filename.match(/.*_buildpack-cached-?(.*)?-v.*.zip/)[1]
      metadata['product_files'].push({
                                         'file' => filename,
                                         'upload_as' => display_name(stack),
                                         'description' => description
                                     })
    end

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
  @lts_product == "true" ? "All Users" : "Admins Only"
end

def eccn
  '5D002'
end

def license_exception
  'TSU'
end

def display_name(stack = '')
  if !stack.empty?
    "#{formatted_name} Buildpack #{stack} (offline)"
  else
    "#{formatted_name} Buildpack (offline)"
  end
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
  elsif buildpack == 'nginx'
    "NGINX"
  else
    "#{buildpack.capitalize}"
  end
end
