require "json"
require "http/client"

module Depwatcher
  module Pypi
    class External
      JSON.mapping(
        releases: Hash(String, Array(Release)),
      )
    end
    class Release
      JSON.mapping(
        ref: String?,
        url: String,
        md5_digest: String,
        packagetype: String,
        size: Int64,
      )
    end
    class Internal
      JSON.mapping(
        ref: String,
      )
      def initialize(@ref : String)
      end
    end

    def self.check(name : String) : Array(Internal)
      releases(name).map do |version, _|
        Internal.new(version)
      end.sort_by { |i| SemanticVersion.new(i.ref) }.last(10)
    end

    def self.in(name : String, ref : String) : Release
      release = releases(name)[ref].select do |r|
        r.packagetype == "sdist"
      end.sort_by do |r|
        r.size
      end.first
      release.ref = ref
      release
    end

    # private

    def self.releases(name : String) : Hash(String, Array(Release))
      response = HTTP::Client.get "https://pypi.python.org/pypi/#{name}/json"
      raise "Could not download data from pypi: code #{response.status_code}" unless response.status_code == 200
      External.from_json(response.body).releases
    end
  end
end
