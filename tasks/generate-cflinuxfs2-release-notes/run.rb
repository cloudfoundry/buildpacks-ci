#!/usr/bin/env ruby

require 'octokit'
require 'open-uri'
require_relative 'release-notes-creator'
require_relative '../../lib/git-client'


previous_version = File.read('previous-cflinuxfs2-release/version').strip
new_version = File.read('version/number').strip

if ENV.fetch('STACK') == 'cflinuxfs2'
  old_receipt_uri = "https://raw.githubusercontent.com/cloudfoundry/cflinuxfs2/#{previous_version}/cflinuxfs2/cflinuxfs2_receipt"
  cve_yaml_file = 'new-cves/new-cve-notifications/ubuntu14.04.yml'
  cves_dir = 'new-cve-notifications'
elsif ENV.fetch('STACK') == 'stacks-nc'
  Octokit.configure do |c|
    c.login    = ENV.fetch('GITHUB_USERNAME')
    c.password = ENV.fetch('GITHUB_PASSWORD')
  end

  old_receipt_uri = Octokit.contents('pivotal-cf/stacks-nc', :path => 'cflinuxfs2/cflinuxfs2_receipt', :ref => previous_version)[:download_url]
  cve_yaml_file = 'new-cves/new-cves-stacks-nc/ubuntu14.04.yml'
  cves_dir = 'new-cves-stacks-nc'
else
  raise "Unsupported stack: #{ENV.fetch('STACK')}"
end

new_receipt_file = 'cflinuxfs2/cflinuxfs2/cflinuxfs2_receipt'
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


robots_cve_dir = File.join('new-cves', cves_dir)
Dir.chdir(robots_cve_dir) do
  GitClient.add_file('ubuntu14.04.yml')
  commit_message = "Updating CVEs for #{ENV.fetch('STACK')} release #{new_version}\n\n"
  GitClient.safe_commit(commit_message)
end

system "rsync -a new-cves/ new-cves-artifacts"
