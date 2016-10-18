#!/usr/bin/env ruby

root_dir      = Dir.pwd

require_relative "./cflinuxfs2-pivnet-metadata-writer"
require_relative "#{root_dir}/buildpacks-ci/lib/git-client"

metadata_dir  = File.join(root_dir, 'rootfs-pivnet-metadata', 'pivnet-metadata')

stack_version_file = File.join(root_dir, 'version', 'number')
stack_version = File.read(stack_version_file)

cflinux_release_version_file = File.join(root_dir, 'cflinuxfs2-rootfs-release-version', 'number')
cflinux_release_version = File.read(cflinux_release_version_file)

writer = Cflinuxfs2PivnetMetadataWriter.new(metadata_dir, stack_version, cflinux_release_version)
writer.run!

Dir.chdir(metadata_dir) do
  GitClient.add_file('rootfs-nc.yml')
  GitClient.safe_commit("Create Pivnet release metadata for Compilerless Rootfs v#{stack_version}")
end

system("rsync -a rootfs-pivnet-metadata/ pivnet-metadata-artifacts")
