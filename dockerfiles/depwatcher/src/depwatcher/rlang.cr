require "./base"
require "xml"

module Depwatcher
  class Rlang < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
      )
      def initialize(@ref : String, @url : String)
      end
    end

    def check() : Array(Internal)
      response = client.get "https://svn.r-project.org/R/tags/"
      doc = XML.parse_html(response)
      lis = doc.xpath("//li/a")
      raise "Could not parse r svn website" unless lis.is_a?(XML::NodeSet)

      lis.map do |a|
        href = a["href"].to_s
        m = href.match(/^R\-([\d\-]+)\//)
        version = m[1].gsub("-", ".") if m
        Internal.new(version) if version
      end.compact.sort_by { |i| SemanticVersion.new(i.ref) }.last(10)
    end

    def in(ref : String) : Release
      major = ref.split(".")[0]
      Release.new(ref, "https://cran.cnr.berkeley.edu/src/base/R-#{major}/R-#{ref}.tar.gz")
    end
  end
end
