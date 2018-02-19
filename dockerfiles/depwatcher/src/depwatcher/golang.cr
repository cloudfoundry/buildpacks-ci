require "json"
require "http/client"
require "xml"

module Depwatcher
  module Golang
    class Internal
      JSON.mapping(
        ref: String,
      )
      def initialize(@ref : String)
      end
    end
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def self.check() : Array(Internal)
      all.map do |r|
        Internal.new(r.ref)
      end.reverse
    end

    def self.in(ref : String) : Release
      r = all.find do |r|
        r.ref == ref
      end
      raise "Could not find data for version" unless r
      r
    end

    def self.all() : Array(Release)
      context = OpenSSL::SSL::Context::Client.insecure
      response = HTTP::Client.get("https://golang.org/dl/", tls: context)
      doc = XML.parse_html(response.body)
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
