require "json"
require "http/client"
require "xml"

module Depwatcher
  module RubygemsCli
    class Internal
      JSON.mapping(
        ref: String,
        url: String,
      )
      def initialize(@ref : String, @url : String)
      end
    end
    class Release
      JSON.mapping(
        ref: String,
        url: String,
      )
      def initialize(@ref : String, @url : String)
      end
    end

    def self.check() : Array(Internal)
      response = HTTP::Client.get "https://rubygems.org/pages/download"
      doc = XML.parse_html(response.body)
      links = doc.xpath("//a[contains(@class,'download__format')][text()='tgz']")
      raise "Could not parse rubygems download website" unless links.is_a?(XML::NodeSet)
      links.map do |a|
        v = a["href"].gsub(/.*\/rubygems\-(.*)\.tgz$/, "\\1")
        Internal.new(v, a["href"])
      end
    end

    def self.in(ref : String) : Release
      return Release.new(ref, "https://rubygems.org/rubygems/rubygems-#{ref}.tgz")
    end
  end
end
