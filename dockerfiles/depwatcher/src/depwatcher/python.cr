require "./base"
require "xml"

module Depwatcher
  class Python < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        md5_digest: String,
        sha256: String
      )
      def initialize(@ref : String, @url : String, @md5_digest : String, @sha256 : String)
      end
    end

    def check() : Array(Internal)
      response = client.get("https://www.python.org/downloads/").body
      doc = XML.parse_html(response)
      lis = doc.xpath("//*[contains(@class,'release-number')]/a")
      raise "Could not parse python website" unless lis.is_a?(XML::NodeSet)
      lis.map do |a|
        v = a.text.gsub(/^\s*Python\s*/, "")
        Internal.new(v)
      end.first(50).reverse
    end

    def in(ref : String) : Release
      response = client.get("https://www.python.org/downloads/release/python-#{ref.gsub(/\D/,"")}/").body
      doc = XML.parse_html(response)
      a = doc.xpath("//a[contains(text(),'Gzipped source tarball')]")
      raise "Could not parse python release (a) website" unless a.is_a?(XML::NodeSet)
      a = a.first
      tr = a.xpath("./ancestor::tr")
      raise "Could not parse python release (tr) website" unless tr.is_a?(XML::NodeSet)
      tr = tr.first
      md5_digest = tr.xpath("./td[position()=4]")
      raise "Could not parse python release (md5_digest) website" unless md5_digest.is_a?(XML::NodeSet)

      Release.new(ref, a["href"], md5_digest.first.text, get_sha256(a["href"]))
    end
  end
end
