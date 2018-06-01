require "./base"
require "./github_tags"
require "xml"

module Depwatcher
  class Ruby < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check() : Array(Internal)
      name = "ruby/ruby"
      regexp = "^v\\d+_\\d+_\\d+$"
      GithubTags.new(client).matched_tags(name, regexp).map do |r|
        r.ref = r.ref.gsub("_", ".").gsub(/^v/, "")
        r
      end.sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(ref : String) : Release
      releases().select do |r|
        r.ref == ref
      end.first
    end

    private def releases() : Array(Release)
      response = client.get("https://www.ruby-lang.org/en/downloads/").body
      doc = XML.parse_html(response)
      lis = doc.xpath("//li/a[starts-with(text(),'Ruby ')]")
      raise "Could not parse ruby website" unless lis.is_a?(XML::NodeSet)

      lis.map do |a|
        parent = a.parent
        version = a.text.gsub(/^Ruby /, "")
        url = a["href"]
        m = /sha256: ([0-9a-f]+)/.match(parent.text) if parent.is_a?(XML::Node)
        sha = m[1] if m
        Release.new(version, url, sha) if url && sha
      end.compact
    end
  end
end
