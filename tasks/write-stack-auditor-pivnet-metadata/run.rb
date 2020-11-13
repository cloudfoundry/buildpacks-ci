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

def release_notes
  version = get_version

  return "https://github.com/cloudfoundry/stack-auditor/releases/tag/v#{version}"
end

description =
  <<~HEREDOC.chomp
  Buildpack extensions is a suite of add-on tools that assist in work related to buildpacks.

  Stack Auditor:
  - Stack Auditor can assist with migrating applications from one stack to another. The tool is a cf-cli plugin with audit, change, and delete stack commands. For more information see: https://docs.pivotal.io/pivotalcf/2-4/adminguide/stack-auditor.html
  - To install, follow the Installation Steps outlined here: https://github.com/cloudfoundry/stack-auditor
  - For release notes, see: #{release_notes}
HEREDOC

metadata_file_name = "stack-auditor.yml"
metadata_yml = File.join(Dir.pwd, "pivnet-metadata-artifacts", metadata_file_name)
version = get_version

metadata = {}
metadata['release'] = {
    'version' => version,
    'release_type' => "Minor Release",
    'eula_slug' => "vmware_eula",
    'release_notes_url' => release_notes,
    'availability' => "All Users",
    'description' => description
}

artifacts = [ "darwin", "linux", "windows" ]
metadata['product_files'] = []
artifacts.each do |os|
  extension = os == "windows" ? "zip" : "tgz"
  filename = "plugin-release/stack-auditor-#{version}-#{os}.#{extension}"
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


