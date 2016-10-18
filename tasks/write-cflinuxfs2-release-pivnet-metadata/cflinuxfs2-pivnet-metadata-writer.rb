require 'yaml'

class Cflinuxfs2PivnetMetadataWriter

  attr_reader :output_dir, :stack_version, :release_version

  def initialize(output_dir, stack_version, release_version)
    @output_dir = output_dir
    @stack_version = stack_version
    @release_version = release_version
  end


  def run!
    metadata_yml = File.join(output_dir, 'rootfs-nc.yml')

    pivotal_internal_early_access_group_id = '6'

    metadata = {}

    metadata_release = {}
    metadata_release['version'] = "Compilerless RootFS v#{stack_version}"
    metadata_release['release_type'] = 'Beta Release'
    metadata_release['eula_slug'] = 'pivotal_beta_eula'
    metadata_release['availability'] = 'Selected User Groups Only'
    metadata_release['user_group_ids'] = [pivotal_internal_early_access_group_id]

    metadata['release'] = metadata_release

    metadata_files = []
    release = { 'file' => "files-to-upload/cflinuxfs2-nc-rootfs-#{release_version}.tgz",
              'upload_as' => "BOSH release of Compilerless RootFS",
              'description' => 'BOSH release of Compilerless RootFS for PCF'
    }
    deployment_instructions = { 'file' => 'files-to-upload/README.md',
                                'upload_as' => 'Deployment Instructions',
                                'description' => 'Deployment instructions for the BOSH release of Compilerless RootFS for PCF'
    }
    metadata_files.push release
    metadata_files.push deployment_instructions
    metadata['product_files'] = metadata_files


    puts "Writing metadata to #{metadata_yml}"
    puts metadata.to_yaml
    puts "\n\n"

    File.write(metadata_yml, metadata.to_yaml)
  end
end

