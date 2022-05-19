require "./base"
require "./semver"

module Depwatcher
  class NodeLTS < Base
    class Dist
      JSON.mapping(
        shasum: String,
        tarball: String,
      )
    end

    class Version
      JSON.mapping(
        name: String,
        version: String,
        dist: Dist,
      )
    end

    class External
      JSON.mapping(
        versions: Hash(String, Version),
      )
    end

    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )

      def initialize(@ref, @url, @sha256)
      end
    end

    def check : Array(Internal)
      version_numbers().map do |v|
        Internal.new(v)
      end.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      Release.new(ref, url(ref), shasum256(ref))
    end

    private def getLTSLine : String
      response = HTTP::Client.get("https://nodejs.org/en/about/releases/")
      doc = XML.parse_html(response.body)
      list = doc.xpath_nodes("//table[@class='release-schedule']")[0].children[3]
      lts_version = list.children
        .select() { |item| item.children && item.children.size > 3 && item.children[3].text == "Active LTS" }
        .map() { |item| item.children[1].text }[0]
      return lts_version.sub(/^v/, "")
    end

    private def url(version : String) : String
      "https://nodejs.org/dist/v#{version}/node-v#{version}.tar.gz"
    end

    private def shasum256(version : String) : String
      response = client.get("https://nodejs.org/dist/v#{version}/SHASUMS256.txt").body
      response.lines.select() { |line|
        line.ends_with?("node-v#{version}.tar.gz")
      }.first.split(2).first
    end

    private def version_numbers : Array(String)
      latest_lts = getLTSLine()
      response = client.get("https://nodejs.org/dist/").body
      html = XML.parse_html(response).children[1].children[3].children[3]
      return html.children.select() { |child|
        child.type.element_node?
      }.map() { |c| c["href"] }.select() { |link|
        link.starts_with?("v") && link.ends_with?("/")
      }.map() { |link| link.[1...-1] }.select() { |v|
        semver = Semver.new(v)
        semver.major == latest_lts.to_i
      }
    end
  end
end
