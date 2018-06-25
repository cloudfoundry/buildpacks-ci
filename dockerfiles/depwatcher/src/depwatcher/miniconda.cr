require "./base"
require "./semantic_version"
require "xml"
require "http/request"

module Depwatcher
  class Miniconda < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        md5: String,
      )
      def initialize(@ref : String, @url : String, @md5 : String)
      end
    end

    def check(generation : String) : Array(Internal)
      releases(generation) { |m, _| Internal.new(m[1]) }
    end

    def in(generation : String, ref : String) : Release
      url = "https://repo.continuum.io/miniconda/Miniconda#{generation}-#{ref}-Linux_x86_64.sh"
      (releases(generation) { |m, e|
        if m[1] == ref
          Release.new(ref, url, e.children[7].text)
        end
      }).first
    end

    private def releases(generation : String, &block) : Array
      response = client.get("https://repo.continuum.io/miniconda/").body
      doc = XML.parse_html(response)
      elements = doc.xpath_nodes("//tr[td[a[starts-with(@href,'Miniconda#{generation}')]]]")
      elements.map do |e|
        m = /Miniconda#{generation}-([\d\.]+)-Linux-x86_64.sh/.match(e.text)
        if !m.nil?
          yield m, e
        end
      end.compact
    end

  end
end
