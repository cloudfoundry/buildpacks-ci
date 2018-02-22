require "json"
require "http/client"
require "xml"

module Depwatcher
  module Rlang
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
      )
      def initialize(@ref : String, @url : String)
      end
    end

    def self.check() : Array(Internal)
      response = HTTP::Client.get "https://svn.r-project.org/R/tags/"
      doc = XML.parse_html(response.body)
      lis = doc.xpath("//li/a")
      raise "Could not parse r svn website" unless lis.is_a?(XML::NodeSet)

      lis.map do |a|
        href = a["href"].to_s
        m = href.match(/^R\-([\d\-]+)\//)
        version = m[1].gsub("-", ".") if m
        Internal.new(version) if version
      end.compact.sort_by { |i| SemanticVersion.new(i.ref) }.last(10)
    end

    def self.in(ref : String) : Release
      major = ref.split(".")[0]
      Release.new(ref, "https://cran.cnr.berkeley.edu/src/base/R-#{major}/R-#{ref}.tar.gz")
    end
  end
end
