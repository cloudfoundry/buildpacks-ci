require "./base"
require "xml"

module Depwatcher
  class Go < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def initialize(@client = HTTPClientInsecure.new)
    end

    def check() : Array(Internal)
      releases.map do |r|
        Internal.new(r.ref)
      end.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      r = releases.find do |r|
        r.ref == ref
      end
      raise "Could not find data for version" unless r
      r
    end

    private def releases() : Array(Release)
      response = client.get("https://go.dev/dl/").body
      doc = XML.parse_html(response)
      trs = doc.xpath("//tr[td[contains(text(),'Source')]]")
      raise "Could not parse golang release (td) website" unless trs.is_a?(XML::NodeSet)
      trs.map do |tr|  
        release_name = tr.xpath("./td[1]/a/text()").to_s
        version = release_name.match(/go([\d\.]*)\.src/)
        url = "https://dl.google.com/go/#{release_name}"
        sha = tr.xpath("./td[6]/tt/text()").to_s
        if version.nil?
          nil
        else
          Release.new(version[1], url, sha)
        end
      end.compact
    end
  end
end
