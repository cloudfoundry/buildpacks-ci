#! /usr/bin/env ruby

require 'yaml'
require 'tmpdir'
require 'digest/md5'

data = {} # uri -> md5

release_tag_shas = `git ls-remote --tags`.split("\n").map(&:split).map(&:first)
release_tag_shas.each do |release_sha|
  begin
    manifest_contents = `git show #{release_sha}:manifest.yml 2>&1`

    next unless $?.success?

    manifest = YAML.load(manifest_contents)

    manifest["dependencies"].each do |dependency|
      next if data[dependency["uri"]]

      if dependency.key?( "md5")
        data[dependency["uri"]] = { "md5" => dependency["md5"], "sha" => release_sha }
      end
    end
  rescue Exception => e
    STDERR.puts "failed to parse manifest at #{release_sha}: #{e}"
  end
end

mismatches = []

Dir.mktmpdir do |tmpdir_path|
  Dir.chdir(tmpdir_path) do
    puts "working in #{tmpdir_path}"

    data.each do |uri, metadata_hash|
      desired_md5 = metadata_hash['md5']
      release_tag_sha = metadata_hash['sha']
      file = uri.gsub(/[^a-zA-Z0-9\.]/, "_")

      system "wget -q -c #{uri} -O #{file}"
      actual_md5 = Digest::MD5.file(file).to_s



      if desired_md5 == actual_md5
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
