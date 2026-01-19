require "./base"
require "xml"

module Depwatcher
  class Python < Base
    class Release
      include JSON::Serializable

      property ref : String
      property url : String
      property md5_digest : String
      property sha256 : String

      def initialize(@ref : String, @url : String, @md5_digest : String, @sha256 : String)
      end
    end

    def check : Array(Internal)
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
      response = client.get("https://www.python.org/downloads/release/python-#{ref.gsub(/\D/, "")}/").body
      doc = XML.parse_html(response)
      a = doc.xpath("//a[contains(text(),'Gzipped source tarball')]")
      raise "Could not parse python release (a) website" unless a.is_a?(XML::NodeSet)
      a = a.first
      tr = a.xpath("./ancestor::tr")
      raise "Could not parse python release (tr) website" unless tr.is_a?(XML::NodeSet)
      tr = tr.first
      # Try column 8 first (Python 3.12.12+ with Sigstore+SBOM), fallback to column 7 (Python 3.9-3.11)
      # Python 3.12.12+: 8 columns including Sigstore (colspan=2 counts as 1 td) and SBOM, MD5 in column 8
      # Python 3.9-3.11: 7 columns, MD5 in column 7
      md5_digest = tr.xpath("./td[position()=8]")
      if md5_digest.is_a?(XML::NodeSet) && md5_digest.size == 0
        md5_digest = tr.xpath("./td[position()=7]")
      end
      raise "Could not parse python release (md5_digest) website" unless md5_digest.is_a?(XML::NodeSet) && md5_digest.size > 0

      Release.new(ref, a["href"], md5_digest.first.text, get_sha256(a["href"]))
    end
  end
end
