#!/usr/bin/env ruby

require 'open-uri'
require_relative 'release-notes-creator'
require_relative '../../lib/git-client'

if ENV['STACK'] == 'stacks'
  github_repo = 'cloudfoundry/stacks'
elsif ENV['STACK'] == 'stacks-nc'
  github_repo = 'pivotal-cf/stacks-nc'
else
  raise "Unsupported stack: #{ENV['STACK']}"
end

previous_version = File.read('previous-stacks-release/version').strip
new_version = File.read('version/number').strip

cve_yaml_file = 'new-cves/ubuntu14.04.yaml'
new_receipt_file = 'stacks/cflinuxfs2/cflinuxfs2_receipt'
old_receipt_file = open("https://raw.githubusercontent.com/#{github_repo}/#{previous_version}/cflinuxfs2/cflinuxfs2_receipt")

body_file = 'release-body/body'
notes = ReleaseNotesCreator.new(cve_yaml_file, old_receipt_file, new_receipt_file)
puts notes
File.write(body_file, notes)

cves = YAML.load_file(cve_yaml_file)

updated_cves = cves.map do |cve|
  if cve['stack_release'] == 'unreleased'
    cve['stack_release'] = new_version
  end
  cve
end

File.write(cve_yaml_file, updated_cves.to_yaml)

Dir.chdir('new-cves') do
  GitClient.add_file('ubuntu14.04.yaml')
  commit_message = "Updating CVEs for #{ENV['STACK']} release #{new_version}\n\n[ci skip]"
  GitClient.safe_commit(commit_message)
end

system "rsync -a new-cves/ new-cves-artifacts"
