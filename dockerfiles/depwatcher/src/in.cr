require "./depwatcher/*"
require "json"

dir = ARGV[0]
data = JSON.parse(STDIN)
STDERR.puts data.to_json
source = data["source"]
version = data["version"]

case type = source["type"].to_s
when "github_releases"
  version = if source["fetch_source"]? == JSON.parse("true")
              Depwatcher::GithubReleases.new.in(source["repo"].to_s, version["ref"].to_s, dir)
            else
              Depwatcher::GithubReleases.new.in(source["repo"].to_s, source["extension"].to_s, version["ref"].to_s, dir)
            end
when "github_tags"
  version = Depwatcher::GithubTags.new.in(source["repo"].to_s, version["ref"].to_s)
when "jruby"
  version = Depwatcher::JRuby.new.in(version["ref"].to_s)
when "miniconda"
  version = Depwatcher::Miniconda.new.in(source["generation"].to_s, version["ref"].to_s)
when "rubygems"
  version = Depwatcher::Rubygems.new.in(source["name"].to_s, version["ref"].to_s)
when "rubygems_cli"
  version = Depwatcher::RubygemsCli.new.in(version["ref"].to_s)
when "pypi"
  version = Depwatcher::Pypi.new.in(source["name"].to_s, version["ref"].to_s)
when "ruby"
  version = Depwatcher::Ruby.new.in(version["ref"].to_s)
when "php"
  version = Depwatcher::Php.new.in(version["ref"].to_s)
when "python"
  version = Depwatcher::Python.new.in(version["ref"].to_s)
when "go"
  version = Depwatcher::Go.new.in(version["ref"].to_s)
when "r"
  version = Depwatcher::R.new.in(version["ref"].to_s)
when "node"
  version = Depwatcher::Node.new.in(version["ref"].to_s)
when "npm"
  version = Depwatcher::Npm.new.in(source["name"].to_s, version["ref"].to_s)
when "nginx"
  version = Depwatcher::Nginx.new.in(version["ref"].to_s)
when "openresty"
  version = Depwatcher::Openresty.new.in(version["ref"].to_s)
when "httpd"
  version = Depwatcher::Httpd.new.in(version["ref"].to_s)
when "ca_apm_agent"
  version = Depwatcher::CaApmAgent.new.in(version["ref"].to_s)
when "appd_agent"
  version = Depwatcher::AppDynamicsAgent.new.in(version["ref"].to_s)
when "dotnet-sdk"
  version = Depwatcher::DotnetSdk.new.in(version["ref"].to_s, dir)
when "dotnet-runtime"
  version = Depwatcher::DotnetRuntime.new.in(version["ref"].to_s, dir)
when "dotnet-aspnetcore"
  version = Depwatcher::AspnetcoreRuntime.new.in(version["ref"].to_s, dir)
when "rserve"
  version = Depwatcher::CRAN.new.in("Rserve", version["ref"].to_s)
when "forecast"
  version = Depwatcher::CRAN.new.in("forecast", version["ref"].to_s)
when "shiny"
  version = Depwatcher::CRAN.new.in("shiny", version["ref"].to_s)
when "plumber"
  version = Depwatcher::CRAN.new.in("plumber", version["ref"].to_s)
else
  raise "Unknown type: #{type}"
end

if version
  File.write("#{dir}/data.json", {source: source, version: version}.to_json)
  STDERR.puts version.to_json
  puts({version: data["version"]}.to_json)
else
  raise "Unable to retrieve version:\n#{data}"
end
