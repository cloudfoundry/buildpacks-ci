require "./depwatcher/*"
require "json"

data = JSON.parse(STDIN)
STDERR.puts data.to_json
source = data["source"]

case type = source["type"].to_s
when "github_releases"
  versions = Depwatcher::GithubReleases.new.check(source["repo"].to_s)
when "github_tags"
  versions = Depwatcher::GithubTags.new.check(source["repo"].to_s, source["regexp"].to_s)
when "rubygems"
  versions = Depwatcher::Rubygems.new.check(source["name"].to_s)
when "rubygems_cli"
  versions = Depwatcher::RubygemsCli.new.check
when "pypi"
  versions = Depwatcher::Pypi.new.check(source["name"].to_s)
when "ruby"
  versions = Depwatcher::Ruby.new.check
when "python"
  versions = Depwatcher::Python.new.check
when "go"
  versions = Depwatcher::Go.new.check
when "r"
  versions = Depwatcher::R.new.check
when "npm"
  versions = Depwatcher::Npm.new.check(source["name"].to_s)
when "nginx"
  versions = Depwatcher::Nginx.new.check
when "httpd"
  versions = Depwatcher::Httpd.new.check
when "ca_apm_agent"
  versions = Depwatcher::CaApmAgent.new.check
when "appd_agent"
  versions = Depwatcher::AppDynamicsAgent.new.check
else
  raise "Unkown type: #{source["type"]}"
end

# Filter out irrelevant versions
version_filter = source["version_filter"]?
if version_filter
  filter = SemanticVersionFilter.new(version_filter.to_s)
  versions.select! do |v|
    filter.match(SemanticVersion.new(v.ref))
  end
end

# Filter out versions concourse already knows about
version = data["version"]?
if version
  ref = SemanticVersion.new(version["ref"].to_s) rescue nil
  versions.reject! do |v|
    SemanticVersion.new(v.ref) < ref
  end if ref
end

puts versions.to_json
