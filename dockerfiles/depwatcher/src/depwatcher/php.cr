require "./base"
require "./semantic_version"
require "xml"
require "http/request"

module Depwatcher
  class Php < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check() : Array(Internal)
      response = client.get("https://secure.php.net/downloads.php").body
      doc = XML.parse_html(response)
      links = doc.xpath_nodes("//h3[starts-with(@id,'v')]/@id")
      links.map { |e| e.content }.map { |v|
        Internal.new(v[1..-1])
      }.sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(ref : String) : Release
      url = "https://php.net/distributions/php-#{ref}.tar.gz"
      response = client.get("https://secure.php.net/downloads.php").body
      doc = XML.parse_html(response)
      links = doc.xpath_nodes("//h3[@id=\"v#{ref}\"]/following-sibling::div/ul/li[a[contains(@href,\".tar.gz\")]]/span[@class='sha256']")
      Release.new(ref, url, links.first.text.to_s)
    end
  end
end
