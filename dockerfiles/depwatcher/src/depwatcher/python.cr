require "json"
require "http/client"
require "xml"

module Depwatcher
  module Python
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
        md5: String,
      )
      def initialize(@ref : String, @url : String, @md5 : String)
      end
    end

    def self.check() : Array(Internal)
      response = HTTP::Client.get "https://www.python.org/downloads/"
      doc = XML.parse_html(response.body)
      lis = doc.xpath("//*[contains(@class,'release-number')]/a")
      raise "Could not parse python website" unless lis.is_a?(XML::NodeSet)
      lis.map do |a|
        v = a.text.gsub(/^\s*Python\s*/, "")
        Internal.new(v)
      end.first(10).reverse
    end

    def self.in(ref : String) : Release
      response = HTTP::Client.get "https://www.python.org/downloads/release/python-#{ref.gsub(/\D/,"")}/"
      doc = XML.parse_html(response.body)
      a = doc.xpath("//a[contains(text(),'Gzipped source tarball')]")
      raise "Could not parse python release (a) website" unless a.is_a?(XML::NodeSet)
      a = a.first
      tr = a.xpath("./ancestor::tr")
      raise "Could not parse python release (tr) website" unless tr.is_a?(XML::NodeSet)
      tr = tr.first
      md5 = tr.xpath("./td[position()=4]")
      raise "Could not parse python release (md5) website" unless md5.is_a?(XML::NodeSet)

      return Release.new(ref, a["href"], md5.first.text)
    end
  end
end
