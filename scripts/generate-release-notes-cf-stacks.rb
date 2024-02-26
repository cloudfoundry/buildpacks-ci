require 'octokit'
require 'open-uri'
require './lib/release-notes-creator'

def generate_release_notes
  stack_repo = ARGV[0]
  current_version = ARGV[1]
  stack = ARGV[3]
  gh_token = ARGV[2]

  temp_dir = Dir.mktmpdir

  release_notes = File.open('release-notes', 'w')

  Dir.chdir(temp_dir) do
    if current_version.split('.')[1] == '0'
      puts "This is the first minor version, no previous version to compare"
      exit
    end

    previous_version = current_version.sub(/(\d+)\.(\d+)\.(\d+)/) do |match|
      major, minor, patch = $1.to_i, $2.to_i, $3.to_i
      "#{major}.#{minor - 1}.#{patch}"
    end

    puts "Genreating release notes for repo: #{stack_repo}"

    receipt_file_name = "receipt.#{stack}.x86_64"

    client = Octokit::Client.new(access_token: gh_token)

    old_receipt_encoded_contents = client.contents("#{stack_repo}", path: "#{receipt_file_name}", query: { ref: "#{previous_version}" })
    old_receipt_contents = Base64.decode64(old_receipt_encoded_contents.content)
    old_receipt = File.open('old-receipt', 'w')
    File.write(old_receipt.path, old_receipt_contents)

    new_receipt_encoded_contents = client.contents("#{stack_repo}", path: "#{receipt_file_name}", query: { ref: "#{current_version}" })
    new_receipt_contents = Base64.decode64(new_receipt_encoded_contents.content)
    new_receipt = File.open('new-receipt', 'w')
    File.write(new_receipt.path, new_receipt_contents)

    dummy_cves_yaml_file = File.open('dummy-cves.yaml', 'w')
    File.write(dummy_cves_yaml_file.path, "---
- title: 'Test'
  stack_release: 0.0.0")

    notes = RootfsReleaseNotesCreator.new(dummy_cves_yaml_file.path, old_receipt.path, new_receipt.path).release_notes
    output = "Release notes #{previous_version} -> #{current_version}: \n\n#{notes}"

    release_notes.write(output)
    release_notes.close
  end

  FileUtils.rm_rf(temp_dir)
end

generate_release_notes