require "./depwatcher/*"
require "json"

data = JSON.parse(STDIN)
STDERR.puts data.to_json
source = data["source"]

case type = source["type"].to_s
when "rubygems"
  versions = Depwatcher::Rubygems.check(source["name"].to_s)
when "pypi"
  versions = Depwatcher::Pypi.check(source["name"].to_s)
else
  raise "Unkown type: #{source["type"]}"
end

version = data["version"]?
if version
  ref = SemanticVersion.new(version["ref"].to_s)
  versions.reject! do |v|
    SemanticVersion.new(v.ref) < ref
  end
end
puts versions.to_json
