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
      response = client.get("https://golang.org/dl/").body
      doc = XML.parse_html(response)
      tds = doc.xpath("//td[contains(text(),'Source')]")
      raise "Could not parse golang release (td) website" unless tds.is_a?(XML::NodeSet)
      tds.map do |td|
        # Get last preceding h3 category header (Stable versions, Unstable verions, Archived versions)
        div = td.xpath("./ancestor::div")
        raise "Could not parse golang release (div) website" unless div.is_a?(XML::NodeSet)
        div = div.skip(div.size - 1).first
        h3 = div.xpath("../preceding-sibling::h3")
        raise "Could not parse golang release (h3) website" unless h3.is_a?(XML::NodeSet)
        h3 = h3.skip(h3.size - 1).first

        # Get entire row, in order to get sha and url
        tr = td.xpath("./ancestor::tr")
        raise "Could not parse golang release (tr) website" unless tr.is_a?(XML::NodeSet)
        tr = tr.first
        sha = tr.xpath("./td[position()=6]")
        raise "Could not parse golang release (sha256) website" unless sha.is_a?(XML::NodeSet)

        a = tr.xpath(".//a")
        raise "Could not parse golang release (a) website" unless a.is_a?(XML::NodeSet)
        url = "https://dl.google.com/go/" + a.first.text

        # Extract versions from Stable and Archived versions; ignore Unstable
        if h3.text().starts_with?("Stable versions")
          v = url.match(/\/go([\d\.]*)\.src/)
          raise "Could not match version in url #{url}" if v.nil?
          Release.new(v[1], url, sha.first.text.to_s)
        elsif h3.text().starts_with?("Archived versions")
          v = url.match(/\/go([\d\.]*)\.src/)
          if v.nil? # Ignore unmatched archived versions (e.g. alpha, beta, rc)
            nil
          else
            Release.new(v[1], url, sha.first.text.to_s)
          end
        else
          nil
        end
      end.compact
    end
  end
end
