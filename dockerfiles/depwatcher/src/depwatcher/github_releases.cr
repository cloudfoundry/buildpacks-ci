require "./base"
require "./semantic_version"

module Depwatcher
  class GithubReleases < Base
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
        tag_name: String,
        draft: Bool,
        prerelease: Bool,
        assets: Array(Asset),
      )
      def ref
        tag_name.gsub(/^v/,"")
      end
    end

    def check(repo : String) : Array(Internal)
      releases(repo).reject do |r|
        r.prerelease || r.draft
      end.map do |r|
        Internal.new(r.ref) if r.ref != ""
      end.compact.sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(repo : String, ref : String) : Release
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

    private def releases(repo : String) : Array(External)
      res = client.get "https://api.github.com/repos/#{repo}/releases"
      Array(External).from_json(res)
    end
  end
end
