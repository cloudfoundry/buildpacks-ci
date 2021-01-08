require "./base"
require "./semver"
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
      versions = links.map { |e| e.content }.map { |v|
        Internal.new(v[1..-1])
      }
      versions += old_versions()
      versions.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      url = "https://php.net/distributions/php-#{ref}.tar.gz"
      response = client.get("https://secure.php.net/downloads.php").body
      doc = XML.parse_html(response)
      links = doc.xpath_nodes("//h3[@id=\"v#{ref}\"]/following-sibling::div/ul/li[a[contains(@href,\".tar.gz\")]]/span[@class='sha256']")
      if links.empty?
        links = links_for_old_versions(ref)
      end
      Release.new(ref, url, links.first.text.to_s.lchop("sha256: "))
    end

    def links_for_old_versions(ref : String) : XML::NodeSet
      response = client.get("https://secure.php.net/releases/").body
      doc = XML.parse_html(response)
      doc.xpath_nodes("//a[text()=\"PHP #{ref} (tar.gz)\"]/following-sibling::span[@class='sha256sum']")
    end

    def old_versions() : Array(Internal)
      response = client.get("https://secure.php.net/releases/").body
      doc = XML.parse_html(response)
      php7_versions = doc.xpath_nodes("//h2[starts-with(text(),\"7.\")]").map { |e| Internal.new(e.content) }
      php8_versions = doc.xpath_nodes("//h2[starts-with(text(),\"8.\")]").map { |e| Internal.new(e.content) }
      [php7_versions, php8_versions].flatten
    end
  end
end
