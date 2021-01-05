require "./base"
require "./semver"
require "xml"
require "http/request"

module Depwatcher
  class Httpd < Base
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
      response = client.get("http://archive.apache.org/dist/httpd/").body
      doc = XML.parse_html(response)
      links = doc.xpath("//a[starts-with(@href, 'CURRENT')]")
      raise "Could not parse apache httpd website" unless links.is_a?(XML::NodeSet)

      links.map do |link|
        href = link["href"].to_s
        m = href.match(/^CURRENT-IS-([\d\.]+)/)
        version = m[1] if m
        Internal.new(version) if version
      end.compact.sort_by { |i| Semver.new(i.ref) }.last(10)
    end

    def in(ref : String) : Release
      res = HTTP::Client.get("http://archive.apache.org/dist/httpd/httpd-#{ref}.tar.bz2.sha256").body
      sha256 = res.split(" ").first
      Release.new(ref, "http://archive.apache.org/dist/httpd/httpd-#{ref}.tar.bz2", sha256)
    end
  end
end
