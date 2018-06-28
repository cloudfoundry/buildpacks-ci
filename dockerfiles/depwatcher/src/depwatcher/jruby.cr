require "./base"
require "./semantic_version"
require "xml"
require "http/request"

module Depwatcher
  class JRuby < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    private def get_versions() : Array(String)
      response = client.get("http://jruby.org/download").body
      doc = XML.parse_html(response)
      elements = doc.xpath_nodes("//a[starts-with(@href,'https://repo1.maven.org/maven2/org/jruby/jruby-dist/')]")
      elements.map { |e|
        m = /https:\/\/repo1.maven.org\/maven2\/org\/jruby\/jruby-dist\/([\d.]+)\/jruby-dist-([\d.]+)-src.zip/.match(e["href"])
        if !m.nil?
          m[1]
        end
      }.compact.uniq
    end

    def check() : Array(Internal)
      get_versions.map { |v|
        Internal.new(v)
      }.sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(ref : String) : Release
      sha = client.get("https://s3.amazonaws.com/jruby.org/downloads/#{ref}/jruby-src-#{ref}.tar.gz.sha256").body.strip
      Release.new(ref, "https://s3.amazonaws.com/jruby.org/downloads/#{ref}/jruby-src-#{ref}.tar.gz", sha)
    end
  end
end
