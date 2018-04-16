#!/usr/bin/env ruby

require 'octokit'
require 'open-uri'
require_relative '../../lib/release-notes-creator'
require_relative '../../lib/git-client'

stack = ENV.fetch('STACK')

previous_version = File.read("previous-#{stack}-release/version").strip

old_receipt_uri = "https://raw.githubusercontent.com/cloudfoundry/#{stack}/#{previous_version}/#{stack}/#{stack}_receipt"
receipt_diff_file = File.join('receipt-diffs', "#{stack}-diff")

new_receipt_file = Dir["receipt-artifacts/#{stack}_receipt*"].first
old_receipt = Tempfile.new('old-receipt')
File.write(old_receipt.path, open(old_receipt_uri).read)

creator = ReleaseNotesCreator.new(nil, old_receipt.path, new_receipt_file)
notes = creator.receipt_diff_section
new_packages = creator.new_packages?

puts notes
old_receipt.unlink

commit_message = "Updating receipt diff for #{stack}\n"
tag_file = File.join('git-tags', 'TAG')
tag_name = ""

if !new_packages
  tag_name = "empty_#{Time.now.to_i}"
  commit_message += "No new packages\n"
else
  tag_name = "newpackages_#{stack}_#{Time.now.to_i}"
  commit_message += "New packages added\n"
end

File.write(tag_file, tag_name)

Dir.chdir('public-robots') do
  File.write(receipt_diff_file, "#{tag_name}:\n\n#{notes}")
  GitClient.add_file(receipt_diff_file)
  GitClient.safe_commit(commit_message)
end

system "rsync -a public-robots/ public-robots-artifacts"
