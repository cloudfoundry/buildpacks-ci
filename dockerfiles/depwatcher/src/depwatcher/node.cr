require "./base"
require "./semver"

module Depwatcher
  class Node < Base
    class NodeRelease
      include JSON::Serializable

      property version : String
      property date : String
      property files : Array(String)
      property npm : String?
      property v8 : String?
      property uv : String?
      property zlib : String?
      property openssl : String?
      property modules : String?
      property lts : String | Bool
      property security : Bool

      def initialize(@version, @date, @files, @npm = nil, @v8 = nil, @uv = nil, @zlib = nil, @openssl = nil, @modules = nil, @lts = false, @security = false)
      end
    end

    class Release
      include JSON::Serializable

      property ref : String
      property url : String
      property sha256 : String

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
      response = client.get("https://nodejs.org/dist/index.json").body
      releases = Array(NodeRelease).from_json(response)
      
      return releases.select { |release|
        version = release.version.lchop('v')
        semver = Semver.new(version)
        # Filter out non LTS versions and old versions (older than 12)
        semver.major % 2 == 0 && semver.major >= 12
      }.map { |release|
        release.version.lchop('v')
      }
    end
  end
end
