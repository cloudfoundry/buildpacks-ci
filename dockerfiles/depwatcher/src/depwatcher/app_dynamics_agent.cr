require "./base"
require "./semver"
require "json"
require "http/request"

module Depwatcher
  class AppDynamicsAgent < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String
      )

      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check() : Array(Internal)
      releases.map do |r|
        Internal.new(r.ref)
      end
    end

    def in(ref : String) : Release
      r = releases.find do |r|
        r.ref == ref
      end
      raise "Could not find data for version" unless r
      r
    end

    private def releases()
      allReleases = Array(Release).new
      response = client.get("https://download.run.pivotal.io/appdynamics-php/index.yml").body
      response.each_line do |appdVersion|
        splitArray = appdVersion.split(": ")
        version = splitArray[0].sub("_", "-")
        url = splitArray[1]
        File.write("#{version}", client.get(url).body)
        sha256 = OpenSSL::Digest.new("sha256").file("#{version}").hexdigest
        File.delete("#{version}")
        allReleases.push(Release.new(version, url, sha256))
      end
      return allReleases.sort_by { |r| Version.new(r.ref) }.last(10)
    end
  end

  class Entry
    JSON.mapping(
      filetype: String,
      os: String,
      bit: {type: String, nilable: true},
      extension: String,
      is_beta: Bool,
      version: String,
      sha256_checksum: {type: String, nilable: true}
    )
  end

  class Version
    include Comparable(self)

    getter original : String
    getter major : Int32
    getter minor : Int32
    getter patch : Int32
    getter metadata : Int32

    # AppDynamics uses a different versioning scheme than SemVer. They use calendar versioning (ref https://community.appdynamics.com/t5/Knowledge-Base/New-in-March-2020-AppDynamics-is-switching-to-calendar/ta-p/38364)
    # So every new release will follow the same pattern: YY.M.P-X  (YY = year, M = month, P = patch, X = metadata). Example: 22.1.0-14
    def initialize(@original : String)
      splitVersion = @original.split(".")
      @major = splitVersion[0].to_i
      @minor = splitVersion[1].to_i
      splitPatch = splitVersion[2].split("-")
      @patch = splitPatch[0].to_i
      @metadata = splitPatch[1].to_i
    end

    def <=>(other : self) : Int32
      r = major <=> other.major
      return r if r != 0
      r = minor <=> other.minor
      return r if r != 0
      r = patch <=> other.patch
      return r if r != 0
      r = metadata <=> other.metadata
      return r if r != 0

      original <=> other.original
    end
  end
end
