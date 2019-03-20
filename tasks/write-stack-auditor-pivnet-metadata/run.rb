#!/usr/bin/env ruby

require 'yaml'

root_dir = Dir.pwd
$product_dir = File.join(root_dir, "plugin-release")

def get_version
  Dir.chdir($product_dir) do
    File.read('version').strip
  end
end

def display_name(os)
  "Stack Auditor #{os}"
end

def description
  File.read(File.join($product_dir, "body"))
end

metadata_file_name = "stack-auditor.yml"
metadata_yml = File.join(Dir.pwd, "pivnet-metadata-artifacts", metadata_file_name)
version = get_version

metadata = {}
metadata['release'] = {
    'version' => version,
    'release_type' => "Minor Release",
    'eula_slug' => "pivotal_software_eula",
    'release_notes_url' => "https://github.com/cloudfoundry/stack-auditor/releases/tag/v#{version}",
}
# metadata['release']['eccn'] = eccn
# metadata['release']['license_exception'] = license_exception

artifacts = [ "darwin", "linux", "windows" ]
metadata['product_files'] = []
artifacts.each do |os|
  extension = os == "windows" ? "zip" : "tgz"
  filename = "../plugin-release/stack-auditor-#{version}-#{os}.#{extension}"
  metadata['product_files'].push({
                                     'file' => filename,
                                     'upload_as' => display_name(os),
                                     'description' => description
                                 })
end

puts "Writing metadata to #{metadata_yml}"
puts metadata.to_yaml
puts "\n\n"

File.write(metadata_yml, metadata.to_yaml)


