require "http/client"
require "xml"

response = HTTP::Client.get("https://www.ruby-lang.org/en/downloads/").body
doc = XML.parse_html(response.body)
lis = doc.xpath("//li/a[starts-with(text(),'Ruby ')]")
raise "Could not parse ruby website" unless lis.is_a?(XML::NodeSet)

lis = lis.map do |a|
  parent = a.parent
  Tuple.new(a.text.gsub(/^Ruby /, ""), a["href"], parent.is_a?(XML::Node) ? parent.text : "")
end
lis = lis.map do |(version, url, text)|
  m = /sha256: ([0-9a-f]+)/.match(text)
  sha = m[1] if m
  [ version, url, m[1] ] if m
end
lis.compact!

puts lis
