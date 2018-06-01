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
      end.reverse
    end

    def in(ref : String) : Release
      r = releases.find do |r|
        r.ref == ref
      end
      raise "Could not find data for version" unless r
      r
    end

    private def releases() : Array(Release)
      response = client.get("https://golang.org/dl/").body
      doc = XML.parse_html(response)
      tds = doc.xpath("//td[contains(text(),'Source')]")
      raise "Could not parse golang release (td) website" unless tds.is_a?(XML::NodeSet)
      tds.map do |td|
        tr = td.xpath("./ancestor::tr")
        raise "Could not parse golang release (tr) website" unless tr.is_a?(XML::NodeSet)
        tr = tr.first
        sha = tr.xpath("./td[position()=6]")
        raise "Could not parse golang release (sha256) website" unless sha.is_a?(XML::NodeSet)
        a = tr.xpath(".//a")
        raise "Could not parse golang release (a) website" unless a.is_a?(XML::NodeSet)
        url = a.first["href"].to_s
        v = url.match(/\/go([\d\.]*)\.src/)
        raise "Could not match version in url #{url}" unless v
        Release.new(v[1], url, sha.first.text.to_s)
      end
    end
  end
end
