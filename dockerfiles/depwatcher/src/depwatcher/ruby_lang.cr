require "json"
require "http/client"
require "xml"

module Depwatcher
  module RubyLang
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def self.check() : Array(GithubTags::Internal)
      name = "ruby/ruby"
      regexp = "^v\\d+_\\d+_\\d+$"
      GithubTags.check(name, regexp).map do |r|
        r.ref = r.ref.gsub("_", ".").gsub(/^v/, "")
        r
      end
    end

    def self.in(ref : String) : Release
      releases().select do |r|
        r.ref == ref
      end.first
    end

    def self.releases() : Array(Release)
      response = HTTP::Client.get "https://www.ruby-lang.org/en/downloads/"
      doc = XML.parse_html(response.body)
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
