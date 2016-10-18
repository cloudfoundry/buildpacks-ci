#!/usr/bin/env ruby

diego_release_dir = ARGV[0]
diego_manifest_file = ARGV[1]
rootfs_release_name = ENV['ROOTFS_RELEASE'] || 'cflinuxfs2-rootfs'

Dir.chdir(diego_release_dir) do
  diego_manifest_contents = File.read(diego_manifest_file)

    to_swap = <<-ROOTFS
    release: cflinuxfs2-rootfs
    ROOTFS

    swapped = <<-ROOTFS
    release: #{rootfs_release_name}
    ROOTFS

    diego_manifest_contents.gsub!(to_swap, swapped)

    to_swap = <<-RELEASE
- name: cflinuxfs2-rootfs
  version: latest
    RELEASE

    swapped = <<-RELEASE
- name: #{rootfs_release_name}
  version: latest
    RELEASE

    diego_manifest_contents.gsub!(to_swap, swapped)

  File.write(diego_manifest_file, diego_manifest_contents)
end



