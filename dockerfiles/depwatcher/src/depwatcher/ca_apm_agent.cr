require "./base"
require "./semver"
require "xml"
require "http/request"
require "openssl"

module Depwatcher
  class CaApmAgent < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String
      )

      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check : Array(Internal)
      response = client.get("https://ca.bintray.com/apm-agents/").body
      doc = XML.parse_html(response)
      links = doc.xpath("//a[@href]")
      raise "Could not parse apache httpd website" unless links.is_a?(XML::NodeSet)

      links.map do |link|
        href = link["href"].to_s
        m = href.match(/^CA-APM-PHPAgent-([\d\.]+)_linux.tar.gz/)
        version = m[1] if m
        Internal.new(version) if version
      end.compact.sort_by { |i| Semver.new(i.ref) }.last(10)
    end

    def in(ref : String) : Release
      url = "https://ca.bintray.com/apm-agents/CA-APM-PHPAgent-#{ref}_linux.tar.gz"
      Release.new(ref, url, get_sha256(url))
    end
  end
end
