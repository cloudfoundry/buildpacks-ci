#!/usr/bin/env ruby

require 'yaml'

puts `ls p-cflinuxfs2-esm-github-release`
release = "p-cflinuxfs2-esm-github-release"
esm_github_bosh_release_path = File.join(release, "source.tar.gz")

metadata_yml = File.join('pivnet-esm-metadata', "esm.yml")
version = File.read(File.join(release, "version")).strip

metadata = {}
metadata['release'] = {
  'version' => version,
  'release_type' => "Minor Release",
  'eula_slug' => 'pivotal_software_eula',
  'availability' => 'Admins Only',
  'eccn' => '5D992',
  #'license_exception' => ""
}

metadata['product_files'] = [
  {
    'file' => esm_github_bosh_release_path,
    'upload_as' => "cflinuxfs2-esm",
    'description' => "CFLinuxfs2 ESM"
  }
]

puts "Writing metadata to #{metadata_yml}"
puts metadata.to_yaml
puts "\n\n"

File.write(metadata_yml, metadata.to_yaml)
