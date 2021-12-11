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
      response = client.get("https://download.appdynamics.com/download/downloadfilelatest?format=json").body
      Entries.from_json(response).results.map do |entry|
        if (entry.filetype == "php-tar" && entry.os == "linux" && entry.bit == "64" && entry.extension == "tar.bz2" && !entry.is_beta)
          Release.new(
            entry.version,
            "https://packages.appdynamics.com/php/#{entry.version}/appdynamics-php-agent-linux_x64-#{entry.version}.tar.bz2",
            entry.sha256_checksum
          )
        else
          nil
        end
      end.compact.sort_by { |r| Version.new(r.ref) }.last(10)
    end
  end

  class Entries
    JSON.mapping(
      results: Array(Entry)
    )
  end

  class Entry
    JSON.mapping(
      filetype: String,
      os: String,
      bit: {type: String, nilable: true},
      extension: String,
      is_beta: Bool,
      version: String,
      sha256_checksum: String
    )
  end

  class Version
    include Comparable(self)

    getter original : String
    getter major : Int32
    getter minor : Int32
    getter patch : Int32
    getter metadata : Int32

    def initialize(@original : String)
      @major, @minor, @patch, @metadata = @original.split(".").map(&.to_i)
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
