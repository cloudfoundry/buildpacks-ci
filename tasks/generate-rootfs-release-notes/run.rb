#!/usr/bin/env ruby

require 'octokit'
require 'open-uri'
require_relative '../../lib/release-notes-creator'
require_relative '../../lib/git-client'

previous_version = File.read('previous-rootfs-release/.git/ref').strip
new_version = File.read('version/number').strip
stack = ENV.fetch('STACK')
ubuntu_version = {
  'cflinuxfs3' => '18.04',
  'cflinuxfs4' => '22.04'
}.fetch(stack) { raise "Unsupported stack: #{stack}" }

stack_repo = ENV.fetch('STACK_REPO', nil)
stack_repo = "cloudfoundry/#{stack}" if stack_repo.nil? || stack_repo.empty?

puts "Generating release notes for repo: #{stack_repo}"

receipt_file_name = "receipt.#{stack}.x86_64"
gh_token = ENV.fetch('GITHUB_ACCESS_TOKEN', nil)

if gh_token.nil? || gh_token.empty?
  old_receipt_uri = "https://raw.githubusercontent.com/#{stack_repo}/#{previous_version}/#{receipt_file_name}"
  old_receipt_contents = URI.open(old_receipt_uri).read
else
  puts 'Using GitHub token to fetch receipt...'
  begin
    client = Octokit::Client.new(access_token: gh_token)
    encoded_contents = client.contents(stack_repo, path: receipt_file_name, ref: previous_version)
    old_receipt_contents = Base64.decode64(encoded_contents.content)
  rescue Octokit::Error => e
    puts "Error fetching receipt: #{e.message}"
  end
end

old_receipt = Tempfile.new('old-receipt')
File.write(old_receipt.path, old_receipt_contents)

cve_yaml_file = "new-cves/new-cve-notifications/ubuntu#{ubuntu_version}.yml"
cves_dir = 'new-cve-notifications'

new_receipt_file = "rootfs/#{receipt_file_name}"
notes = RootfsReleaseNotesCreator.new(cve_yaml_file, old_receipt.path, new_receipt_file).release_notes
puts notes

body_file = 'release-body/body'
File.write(body_file, notes)
old_receipt.unlink

cves = YAML.load_file(cve_yaml_file, permitted_classes: [Date, Time])

updated_cves = cves.map do |cve|
  cve['stack_release'] = new_version if cve['stack_release'] == 'unreleased'
  cve
end

File.write(cve_yaml_file, updated_cves.to_yaml)

robots_cve_dir = File.join('new-cves', cves_dir)
Dir.chdir(robots_cve_dir) do
  GitClient.add_file("ubuntu#{ubuntu_version}.yml")
  commit_message = "Updating CVEs for #{stack} release #{new_version}\n\n"
  GitClient.safe_commit(commit_message)
end

system 'rsync -a new-cves/ new-cves-artifacts'
