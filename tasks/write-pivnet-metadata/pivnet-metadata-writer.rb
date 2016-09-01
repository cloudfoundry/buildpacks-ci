#!/usr/bin/env ruby

require 'yaml'

class PivnetMetadataWriter

  attr_reader :output_dir, :buildpack_dir, :cached_buildpack_filename

  def initialize(output_dir, buildpack_dir, cached_buildpack_filename)
    @output_dir = output_dir
    @buildpack_dir = buildpack_dir
    @cached_buildpack_filename = cached_buildpack_filename
  end

  def get_version
    Dir.chdir(buildpack_dir) do
      File.read('VERSION').strip
    end
  end

  def run!
    metadata_yml = File.join(output_dir, 'dotnet-core.yml')

    metadata = {}
    metadata['release'] = {
      'version' => ".NET Core #{get_version} (BETA)",
      'release_type' => 'Beta Release',
      'eula_slug' => 'pivotal_beta_eula',
      'release_notes_url' => "https://github.com/cloudfoundry-community/dotnet-core-buildpack/releases/tag/v#{get_version}",
      'availability' => 'Admins Only'
    }
    metadata['product_files'] = [ {
      'file' => File.join('pivotal-buildpack-cached', cached_buildpack_filename),
      'upload_as' => '.NET Core Buildpack BETA (offline)',
      'description' => '.NET Core Buildpack BETA for PCF'
    } ]

    puts "Writing metadata to #{metadata_yml}"
    puts metadata.to_yaml
    puts "\n\n"

    File.write(metadata_yml, metadata.to_yaml)
  end
end

