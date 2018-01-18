require "json"
require "http/client"

module Depwatcher
  module Rubygems
    class External
      JSON.mapping(
        number: String,
        sha: String,
        prerelease: Bool,
      )
    end
    class Internal
      JSON.mapping(
        ref: String,
      )
      def initialize(external : External)
        @ref = external.number
      end
    end
    class Release
      JSON.mapping(
        ref: String,
        sha256: String,
      )
      def initialize(external : External)
        @ref = external.number
        @sha256 = external.sha
      end
    end

    def self.check(name : String) : Array(Internal)
      releases(name).reject do |r|
        r.prerelease
      end.map do |r|
        Internal.new(r)
      end.first(10).reverse
    end

    def self.in(name : String, ref : String) : Release
      Release.new(release(name, ref))
    end

    # private

    def self.releases(name : String) : Array(External)
      response = HTTP::Client.get "https://rubygems.org/api/v1/versions/#{name}.json"
      raise "Could not download data from rubygems: code #{response.status_code}" unless response.status_code == 200
      Array(External).from_json(response.body)
    end

    def self.release(name : String, version : String) : External
      response = HTTP::Client.get "https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}.json"
      raise "Could not download data from rubygems: code #{response.status_code}" unless response.status_code == 200
      External.from_json(response.body)
    end
  end
end
