#!/usr/bin/env ruby
require_relative '../../lib/commit'

# For each individual release of a CNB, we filter out all of the commits
# which aren't related to a Tracker story.
def get_changes
  latest_version = `git tag`.split("\n").map{|i| i.strip.gsub('v','') }
    .select{|i| Gem::Version.correct?(i)}.map {|i| Gem::Version.new(i) }.sort.last
  changelog = ""
  commits = Commit.recent(latest_version) rescue nil
  if commits
    commits.each do |commit|
      commit_string = commit.to_s
      if commit_string.include? "www.pivotaltracker.com"
        changelog.concat(commit_string).concat("\n\n")
      end
    end
  end

  changelog.concat("No major changes.\n\n") if changelog == ""

  changelog
end

language = ENV['LANGUAGE']
version=File.read(File.join('version', 'version'))
release_body_file = File.absolute_path(File.join('release-artifacts', 'body'))
release_packaged_bp = File.absolute_path(File.join('release-artifacts', "#{language}-cnb-#{version}"))
packager_path = File.absolute_path(File.join('buildpack', '.bin', 'packager'))

# Need to build packager, to make sure it's compiled for the right OS
Dir.chdir('packager/packager') do
  `go build -o #{packager_path}`
end

Dir.chdir('buildpack') do
  # Need to set the PACKAGE_DIR
  ENV["PACKAGE_DIR"]=release_packaged_bp
  `./scripts/package.sh -a -v #{version}`
  File.write(release_body_file, get_changes)
  File.write(release_body_file, `#{packager_path} -summary`, mode: 'a')
end

File.write('release-artifacts/name', "v#{version}")
File.write('release-artifacts/tag', "v#{version}")
