#!/usr/bin/env ruby

require 'octokit'
require 'open-uri'
require_relative '../../../lib/release-notes-creator'
require_relative '../../../lib/git-client'


previous_version = File.read('previous-rootfs-release/version').strip
new_version = File.read('version/number').strip
stack = ENV.fetch('STACK')
ubuntu_version = {
  'cflinuxfs2' => '14.04',
  'cflinuxfs3' => '18.04',
  'cflinuxfs3m' => '18.04'
}.fetch(stack) or raise "Unsupported stack: #{stack}"

receipt_file_name = stack == 'cflinuxfs2' ? "#{stack}_receipt" : "receipt.#{stack}.x86_64"
receipt_file_dest = stack == 'cflinuxfs2' ? "#{stack}/#{receipt_file_name}" : receipt_file_name

old_receipt_uri = "https://raw.githubusercontent.com/cloudfoundry/#{stack}/master/#{receipt_file_dest}"
cve_yaml_file = "new-cves/new-cve-notifications/ubuntu#{ubuntu_version}.yml"
cves_dir = 'new-cve-notifications'

new_receipt_file = "rootfs/#{receipt_file_name}"
old_receipt = Tempfile.new('old-receipt')
File.write(old_receipt.path, open(old_receipt_uri).read)

body_file = 'release-body/body'
notes = ReleaseNotesCreator.new(cve_yaml_file, old_receipt.path, new_receipt_file).release_notes
puts notes
File.write(body_file, notes)
old_receipt.unlink

cves = YAML.load_file(cve_yaml_file)

updated_cves = cves.map do |cve|
  if cve['stack_release'] == 'unreleased'
    cve['stack_release'] = new_version
  end
  cve
end

File.write(cve_yaml_file, updated_cves.to_yaml)


robots_cve_dir = File.join('new-cves', cves_dir)
Dir.chdir(robots_cve_dir) do
  GitClient.add_file("ubuntu#{ubuntu_version}.yml")
  commit_message = "Updating CVEs for #{stack} release #{new_version}\n\n"
  GitClient.safe_commit(commit_message)
end

system "rsync -a new-cves/ new-cves-artifacts"
