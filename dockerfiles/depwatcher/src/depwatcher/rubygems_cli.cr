require "./base"
require "xml"

module Depwatcher
  class RubygemsCli < Base
    class Release
      include JSON::Serializable

      property ref : String
      property url : String

      def initialize(@ref : String, @url : String)
      end
    end

    def check : Array(Internal)
      response = client.get("https://rubygems.org/pages/download").body
      doc = XML.parse_html(response)
      links = doc.xpath("//div[@id='formats']//a[text()='tgz']")
      raise "Could not parse rubygems download website" unless links.is_a?(XML::NodeSet)
      links.map do |a|
        v = a["href"].gsub(/.*\/rubygems\-(.*)\.tgz$/, "\\1")
        Internal.new(v)
      end
    end

    def in(ref : String) : Release
      return Release.new(ref, "https://rubygems.org/rubygems/rubygems-#{ref}.tgz")
    end
  end
end
