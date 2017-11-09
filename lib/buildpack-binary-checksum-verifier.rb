# encoding: utf-8
require_relative 'git-client'
require 'yaml'
require 'tmpdir'
require 'digest/md5'

class BuildpackBinaryChecksumVerifier
  def self.run!(buildpack_dir, whitelist_file)
    uris_to_ignore = YAML.load_file(whitelist_file)
    uri_to_sha256_mapping = get_checksums_by_uri(buildpack_dir, uris_to_ignore)
    show_mismatches(uri_to_sha256_mapping)
  end

  # uri -> sha256
  def self.get_checksums_by_uri(buildpack_dir, uris_to_ignore)
    data = {}

    release_tag_shas = GitClient.git_tag_shas(buildpack_dir)
    release_tag_shas.each do |release_sha|
      begin
        manifest_contents = GitClient.get_file_contents_at_sha(buildpack_dir, release_sha, 'manifest.yml')
        manifest = YAML.load(manifest_contents)

        manifest["dependencies"].each do |dependency|
          uri = dependency["uri"]
          next if uri.nil?
          next if data[uri]
          next if uris_to_ignore.include?(uri)

          if dependency.key?( "sha256")
            data[uri] = { "sha256" => dependency["sha256"], "sha" => release_sha }
          end
        end
      rescue GitClient::GitError => e
        # No manifest present at that release sha
      rescue Exception => e
        puts "failed to parse manifest at #{release_sha}: #{e}"
      end
    end
    data
  end

  def self.show_mismatches(uri_mapping)
    mismatches = []

    Dir.mktmpdir do |tmpdir_path|
      Dir.chdir(tmpdir_path) do
        puts "working in #{tmpdir_path}"
        uri_mapping.each do |uri, metadata_hash|
          attempts = 0
          max_attempts = 3
          sha256_match = false

          while !sha256_match && attempts < max_attempts do
            desired_sha256 = metadata_hash['sha256']
            release_tag_sha = metadata_hash['sha']

            actual_sha256 = `curl -L -s #{uri} | shasum -a 256 - | cut -d ' ' -f 1`.chomp

            if desired_sha256 == actual_sha256
              sha256_match = true
            else
              attempts += 1
            end
          end

          if sha256_match
            print '.'
          else
            print 'F'
            mismatches << "#{uri}: actual #{actual_sha256} != desired #{desired_sha256}, release sha: #{release_tag_sha}"
          end
        end
      end
    end

    puts ""
    puts mismatches.join("\n")
    mismatches.empty?
  end
end
