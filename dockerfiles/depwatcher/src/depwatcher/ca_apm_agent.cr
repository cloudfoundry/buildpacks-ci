require "./base"
require "./semantic_version"
require "xml"
require "http/request"

module Depwatcher
  class CaApmAgent < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
      )
      def initialize(@ref : String, @url : String)
      end
    end

    def check() : Array(Internal)
      response = client.get("https://ca.bintray.com/apm-agents/").body
      doc = XML.parse_html(response)
      links = doc.xpath("//a[@href]")
      raise "Could not parse apache httpd website" unless links.is_a?(XML::NodeSet)

      links.map do |link|
        href = link["href"].to_s
        m = href.match(/^CA-APM-PHPAgent-([\d\.]+)_linux.tar.gz/)
        version = m[1] if m
        Internal.new(version) if version
      end.compact.sort_by { |i| SemanticVersion.new(i.ref) }.last(10)
    end

    def in(ref : String) : Release
      Release.new(ref, "https://ca.bintray.com/apm-agents/CA-APM-PHPAgent-#{ref}_linux.tar.gz")
    end
  end
end
