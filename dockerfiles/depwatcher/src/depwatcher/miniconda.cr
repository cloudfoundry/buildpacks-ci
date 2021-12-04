require "./base"
require "./semver"
require "xml"
require "http/request"

module Depwatcher
  class Miniconda < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        md5: String,
        sha256: String
      )
      def initialize(@ref : String, @url : String, @md5 : String, @sha256 : String)
      end
    end

    def check(python_version : String) : Array(Internal)
      generation = python_version.split(".")[0]
      releases(generation, python_version) { |m, _| Internal.new(m[1]) }.sort_by { |i| Semver.new(i.ref) }
    end

    def in(python_version : String, ref : String) : Release
      generation = python_version.split(".")[0]
      url = "https://repo.anaconda.com/miniconda/Miniconda#{generation}-py#{python_version.delete(".")}_#{ref}-Linux-x86_64.sh"
      (releases(generation, python_version) { |m, e|
        if m[1] == ref
          Release.new(ref, url, e.children[7].text, get_sha256(url))
        end
      }).first
    end

    private def releases(generation : String, python_version : String, &block) : Array
      response = client.get("https://repo.anaconda.com/miniconda/").body
      doc = XML.parse_html(response)
      elements = doc.xpath_nodes("//tr[td[a[starts-with(@href,'Miniconda#{generation}-py#{python_version.delete(".")}')]]]")
      elements.map do |e|
        m = /Miniconda#{generation}-py#{python_version.delete(".")}_([\d\.]+)-Linux-x86_64.sh/.match(e.text)
        if !m.nil?
          yield m, e
        end
      end.compact
    end
  end
end
