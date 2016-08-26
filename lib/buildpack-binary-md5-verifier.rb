# encoding: utf-8
require_relative 'git-client'
require 'yaml'
require 'tmpdir'
require 'digest/md5'

class BuildpackBinaryMD5Verifier
  def self.run!(buildpack_dir, whitelist_file)
    uris_to_ignore = YAML.load_file(whitelist_file)
    uri_to_md5_mapping = get_uri_md5_sha_values(buildpack_dir, uris_to_ignore)
    show_mismatches(uri_to_md5_mapping)
  end

  # uri -> md5
  def self.get_uri_md5_sha_values(buildpack_dir, uris_to_ignore)
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

          if dependency.key?( "md5")
            data[uri] = { "md5" => dependency["md5"], "sha" => release_sha }
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
          md5_match = false

          while !md5_match && attempts < max_attempts do
            desired_md5 = metadata_hash['md5']
            release_tag_sha = metadata_hash['sha']
            file = uri.gsub(/[^a-zA-Z0-9\.]/, "_")

            system "wget -q -c #{uri} -O #{file}"
            actual_md5 = Digest::MD5.file(file).to_s

            if desired_md5 == actual_md5
              md5_match = true
            else
              attempts += 1
            end
          end

          if md5_match
            print '.'
          else
            print 'F'
            mismatches << "#{uri}: actual #{actual_md5} != desired #{desired_md5}, release sha: #{release_tag_sha}"
          end
        end
      end
    end

    puts ""
    puts mismatches.join("\n")
    mismatches.empty?
  end
end
