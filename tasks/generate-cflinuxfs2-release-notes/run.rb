#!/usr/bin/env ruby

require 'octokit'
require 'open-uri'
require_relative '../../lib/release-notes-creator'
require_relative '../../lib/git-client'


if ENV.fetch('STACK') == 'cflinuxfs2'
  old_receipt_uri = 'previous-cflinuxfs2-release/cflinuxfs2/cflinuxfs2_receipt'
  cve_yaml_file = 'new-cves/new-cve-notifications/ubuntu14.04.yml'
  cves_dir = 'new-cve-notifications'
else
  raise "Unsupported stack: #{ENV.fetch('STACK')}"
end

new_receipt_file = 'cflinuxfs2/cflinuxfs2/cflinuxfs2_receipt'
old_receipt = Tempfile.new('old-receipt')
File.write(old_receipt.path, open(old_receipt_uri).read)

body_file = 'release-body/body'
notes = RootfsReleaseNotesCreator.new(cve_yaml_file, old_receipt.path, new_receipt_file).release_notes
puts notes
File.write(body_file, notes)
old_receipt.unlink

cves = YAML.load_file(cve_yaml_file)

new_version = File.read('version/number').strip
updated_cves = cves.map do |cve|
  if cve['stack_release'] == 'unreleased'
    cve['stack_release'] = new_version
  end
  cve
end

File.write(cve_yaml_file, updated_cves.to_yaml)


robots_cve_dir = File.join('new-cves', cves_dir)
Dir.chdir(robots_cve_dir) do
  GitClient.add_file('ubuntu14.04.yml')
  commit_message = "Updating CVEs for #{ENV.fetch('STACK')} release #{new_version}\n\n"
  GitClient.safe_commit(commit_message)
end

system "rsync -a new-cves/ new-cves-artifacts"
