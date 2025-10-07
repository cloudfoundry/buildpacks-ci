require "./depwatcher/*"
require "json"

data = JSON.parse(STDIN)
source = data["source"]

if source.as_h.has_key?("github_token")
  token = source["github_token"].to_s
  ENV["OAUTH_AUTHORIZATION_TOKEN"] = token
  # To avoid leaking the credential, immediately remove it from the data struct
  source.as_h.delete("github_token")
end
STDERR.puts data.to_json

case type = source["type"].to_s
when "github_releases"
  allow_prerelease = source["prerelease"]?
  if allow_prerelease
    versions = Depwatcher::GithubReleases.new.check(source["repo"].to_s, allow_prerelease.as_bool)
  else
    versions = Depwatcher::GithubReleases.new.check(source["repo"].to_s, false)
  end
when "github_tags"
  versions = Depwatcher::GithubTags.new.check(source["repo"].to_s, source["tag_regex"].to_s)
when "jruby"
  versions = Depwatcher::JRuby.new.check
when "miniconda"
  versions = Depwatcher::Miniconda.new.check(source["python_version"].to_s)
when "rubygems"
  versions = Depwatcher::Rubygems.new.check(source["name"].to_s)
when "rubygems_cli"
  versions = Depwatcher::RubygemsCli.new.check
when "pypi"
  versions = Depwatcher::Pypi.new.check(source["name"].to_s)
when "ruby"
  versions = Depwatcher::Ruby.new.check
when "php"
  version_filter = source["version_filter"]?
  if version_filter
    versions = Depwatcher::Php.new.check(version_filter.to_s)
  else
    versions = Depwatcher::Php.new.check
  end
when "python"
  versions = Depwatcher::Python.new.check
when "go"
  versions = Depwatcher::Go.new.check
when "r"
  versions = Depwatcher::R.new.check
when "npm"
  versions = Depwatcher::Npm.new.check(source["name"].to_s)
when "node"
  version_filter = source["version_filter"]?
  if version_filter && source["version_filter"].to_s == "node-lts"
    versions = Depwatcher::NodeLTS.new.check
  else
    versions = Depwatcher::Node.new.check
  end
when "nginx"
  versions = Depwatcher::Nginx.new.check
when "openresty"
  versions = Depwatcher::Openresty.new.check
when "httpd"
  versions = Depwatcher::Httpd.new.check
when "ca_apm_agent"
  versions = Depwatcher::CaApmAgent.new.check
when "appd_agent"
  versions = Depwatcher::AppDynamicsAgent.new.check
when "dotnet-sdk"
  versions = Depwatcher::DotnetSdk.new.check(source.as_h.fetch("version_filter", "latest").to_s)
when "dotnet-runtime"
  versions = Depwatcher::DotnetRuntime.new.check(source.as_h.fetch("version_filter", "latest").to_s)
when "dotnet-aspnetcore"
  versions = Depwatcher::AspnetcoreRuntime.new.check(source.as_h.fetch("version_filter", "latest").to_s)
when "rserve"
  versions = Depwatcher::CRAN.new.check("Rserve")
when "forecast"
  versions = Depwatcher::CRAN.new.check("forecast")
when "plumber"
  versions = Depwatcher::CRAN.new.check("plumber")
when "shiny"
  versions = Depwatcher::CRAN.new.check("shiny")
when "icu"
  versions = Depwatcher::Icu.new.check
else
  raise "Unkown type: #{source["type"]}"
end

# Filter out irrelevant versions
version_filter = source["version_filter"]?
if version_filter && source["version_filter"].to_s != "node-lts"
  filter = SemverFilter.new(version_filter.to_s)
  versions.select! do |v|
    filter.match(Semver.new(v.ref))
  end

# Special case: when node is invoked as a type github_releases and not explicit type node
elsif type == "github_releases" && version_filter && source["version_filter"].to_s == "node-lts"
  nodeLts = Depwatcher::NodeLTS.new.getLTSLine
  filter = SemverFilter.new("#{nodeLts}.X.X")
  versions.select! do |v|
    filter.match(Semver.new(v.ref))
  end
end

# Filter out versions concourse already knows about
version = data["version"]?
if version
  ref = Semver.new(version["ref"].to_s) rescue nil
  versions.reject! do |v|
    Semver.new(v.ref) < ref
  end if ref
end

puts versions.to_json
