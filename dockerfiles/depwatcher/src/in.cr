require "./depwatcher/*"
require "json"

dir = ARGV[0]
data = JSON.parse(STDIN)
STDERR.puts data.to_json
source = data["source"]
version = data["version"]

case type = source["type"].to_s
when "rubygems"
  version = Depwatcher::Rubygems.in(source["name"].to_s, version["ref"].to_s)
when "rubygems_cli"
  version = Depwatcher::RubygemsCli.in(version["ref"].to_s)
when "pypi"
  version = Depwatcher::Pypi.in(source["name"].to_s, version["ref"].to_s)
when "ruby_lang"
  version = Depwatcher::RubyLang.in(version["ref"].to_s)
when "python"
  version = Depwatcher::Python.in(version["ref"].to_s)
when "golang"
  version = Depwatcher::Golang.in(version["ref"].to_s)
else
  raise "Unkown type: #{type}"
end

File.write("#{dir}/data.json", { source: source, version: version }.to_json)
STDERR.puts version.to_json
puts({ version: data["version"] }.to_json)
