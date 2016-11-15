#!/usr/bin/env ruby

require 'octokit'
require 'open-uri'
require_relative 'release-notes-creator'
require_relative '../../lib/git-client'


previous_version = File.read('previous-stacks-release/version').strip
new_version = File.read('version/number').strip

if ENV['STACK'] == 'stacks'
  old_receipt_uri = "https://raw.githubusercontent.com/cloudfoundry/stacks/#{previous_version}/cflinuxfs2/cflinuxfs2_receipt"
elsif ENV['STACK'] == 'stacks-nc'
  Octokit.configure do |c|
    c.login    = ENV.fetch('GITHUB_USERNAME')
    c.password = ENV.fetch('GITHUB_PASSWORD')
  end

  old_receipt_uri = Octokit.contents('pivotal-cf/stacks-nc', :path => 'cflinuxfs2/cflinuxfs2_receipt', :ref => previous_version)[:download_url]
else
  raise "Unsupported stack: #{ENV['STACK']}"
end

cve_yaml_file = 'new-cves/ubuntu14.04.yml'
new_receipt_file = 'stacks/cflinuxfs2/cflinuxfs2_receipt'
old_receipt_file = open(old_receipt_uri)

body_file = 'release-body/body'
notes = ReleaseNotesCreator.new(cve_yaml_file, old_receipt_file, new_receipt_file).release_notes
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
  GitClient.add_file('ubuntu14.04.yml')
  commit_message = "Updating CVEs for #{ENV['STACK']} release #{new_version}\n\n[ci skip]"
  GitClient.safe_commit(commit_message)
end

system "rsync -a new-cves/ new-cves-artifacts"
