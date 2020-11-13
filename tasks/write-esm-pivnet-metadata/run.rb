#!/usr/bin/env ruby

require 'yaml'

puts `ls -al p-cflinuxfs2-esm-github-release`
release_dir = "p-cflinuxfs2-esm-github-release"

metadata_yml = File.join('pivnet-esm-metadata', "esm.yml")
version = File.read(File.join(release_dir, "version")).strip
esm_github_bosh_release_path = File.join(release_dir, "cflinuxfs2-#{version}.tgz")

metadata = {}
metadata['release'] = {
  'version' => version,
  'release_type' => "Minor Release",
  'eula_slug' => 'vmware_eula',
  'availability' => 'Admins Only',
  'eccn' => '5D992',
  'license_exception' => "NLR"
}

metadata['product_files'] = [
  {
    'file' => esm_github_bosh_release_path,
    'upload_as' => "cflinuxfs2-esm v#{version} BOSH Release",
    'description' => "CFLinuxfs2 ESM"
  }
]

puts "Writing metadata to #{metadata_yml}"
puts metadata.to_yaml
puts "\n\n"

File.write(metadata_yml, metadata.to_yaml)
