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

    class NodeVersionInfo
      JSON.mapping(
        start: String,
        lts: {type: String, nilable: true},
        maintenance: {type: String, nilable: true},
        end: String,
        codename: {type: String, nilable: true},
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
      # Get JSON from github https://raw.githubusercontent.com/nodejs/Release/main/schedule.json

      response = HTTP::Client.get("https://raw.githubusercontent.com/nodejs/Release/main/schedule.json")
      if response.status_code != 200
        raise "Failed to get nodejs LTS schedule"
      end

      latest_lts = ""
      actual_date = Time.local
      actual_year = actual_date.year
      actual_month = actual_date.month
      actual_day = actual_date.day
      Hash(String, NodeVersionInfo).from_json(response.body).map do |version|
        if version[1].lts != nil && version[1].lts != ""
          lts_date = version[1].lts.as(String)
          lts_year = lts_date.split("-")[0].to_i
          lts_month = lts_date.split("-")[1].to_i
          lts_day = lts_date.split("-")[2].to_i
          if lts_year < actual_year || (lts_year == actual_year && lts_month < actual_month) || (lts_year == actual_year && lts_month == actual_month && lts_day <= actual_day)
            latest_lts = version[0].as(String).sub("v","")
          end
        end
        end
      return latest_lts
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
