require "json"
require "http/client"

module Depwatcher
  module GithubReleases
    class Internal
      JSON.mapping(
        ref: String,
      )
      def initialize(@ref : String)
      end
    end
    class Release
      JSON.mapping(
        ref: String,
        url: String,
      )
      def initialize(@ref : String, @url : String)
      end
    end
    class Asset
      JSON.mapping(
        name: String,
        browser_download_url: String,
      )
    end
    class External
      JSON.mapping(
        name: String,
        draft: Bool,
        prerelease: Bool,
        assets: Array(Asset),
      )
      def ref
        name.gsub(/^v/,"")
      end
    end

    def self.check(repo : String) : Array(Internal)
      releases(repo).reject do |r|
        r.prerelease || r.draft
      end.map do |r|
        Internal.new(r.ref) if r.ref != ""
      end.compact.sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def self.in(repo : String, ref : String) : Release
      r = releases(repo).find do |r|
        r.ref == ref
      end
      raise "Could not find data for version" unless r
      a = r.assets.select do |a|
        a.name.match(/gz$/)
      end
      raise "Could not determine a single url for version" unless a.size == 1
      Release.new(r.ref, a[0].browser_download_url)
    end

    # private

    def self.releases(repo : String) : Array(External)
      response = HTTP::Client.get "https://api.github.com/repos/#{repo}/releases"
      raise "Could not download data from github: code #{response.status_code}" unless response.status_code == 200
      Array(External).from_json(response.body)
    end
  end
end
