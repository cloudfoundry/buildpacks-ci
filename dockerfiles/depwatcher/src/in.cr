require "./depwatcher/*"
require "json"

dir = ARGV[0]
data = JSON.parse(STDIN)
STDERR.puts data.to_json
source = data["source"]
version = data["version"]

case type = source["type"].to_s
when "github_releases"
  version = Depwatcher::GithubReleases.new.in(source["repo"].to_s, version["ref"].to_s)
when "rubygems"
  version = Depwatcher::Rubygems.new.in(source["name"].to_s, version["ref"].to_s)
when "rubygems_cli"
  version = Depwatcher::RubygemsCli.new.in(version["ref"].to_s)
when "pypi"
  version = Depwatcher::Pypi.new.in(source["name"].to_s, version["ref"].to_s)
when "ruby_lang"
  version = Depwatcher::RubyLang.new.in(version["ref"].to_s)
when "python"
  version = Depwatcher::Python.new.in(version["ref"].to_s)
when "golang"
  version = Depwatcher::Golang.new.in(version["ref"].to_s)
when "rlang"
  version = Depwatcher::Rlang.new.in(version["ref"].to_s)
when "npm"
  version = Depwatcher::Npm.new.in(source["name"].to_s, version["ref"].to_s)
when "nginx"
  version = Depwatcher::Nginx.new.in(version["ref"].to_s)
else
  raise "Unkown type: #{type}"
end

File.write("#{dir}/data.json", { source: source, version: version }.to_json)
STDERR.puts version.to_json
puts({ version: data["version"] }.to_json)
