require "./base"
require "./github_releases"
require "xml"

module Depwatcher
  class Openresty < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        pgp: String,
        sha256: String
      )
      def initialize(@ref : String, @url : String, @pgp : String, @sha256 : String)
      end
    end

    def check() : Array(Internal)
      name = "openresty/openresty"
      regexp = "\\d+\.\\d+\.\\d+\.\\d+$"
      GithubReleases.new(client).matched_releases(name, regexp).map do |r|
        Internal.new(r.ref.gsub(/^v/, ""))
      end.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      url = "http://openresty.org/download/openresty-#{ref}.tar.gz"
      Release.new(ref, url, "http://openresty.org/download/openresty-#{ref}.tar.gz.asc", get_sha256(url))
    end
  end
end
