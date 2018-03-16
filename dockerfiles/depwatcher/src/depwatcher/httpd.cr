require "./base"
require "xml"

module Depwatcher
  class Httpd < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
      )
      def initialize(@ref : String, @url : String)
      end
    end

    def check() : Array(Internal)
      response = client.get "http://archive.apache.org/dist/httpd/"
      doc = XML.parse_html(response)
      links = doc.xpath("//a[starts-with(@href, 'CURRENT')]")
      raise "Could not parse apache httpd website" unless links.is_a?(XML::NodeSet)

      links.map do |link|
        href = link["href"].to_s
        m = href.match(/^CURRENT-IS-([\d\.]+)/)
        version = m[1] if m
        Internal.new(version) if version
      end.compact.sort_by { |i| SemanticVersion.new(i.ref) }.last(10)
    end

    def in(ref : String) : Release
      Release.new(ref, "http://archive.apache.org/dist/httpd/httpd-#{ref}.tar.bz2")
    end
  end
end
