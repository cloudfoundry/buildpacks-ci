require "./base"
require "./github_tags"
require "xml"

module Depwatcher
  class Nginx < Base
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
      name = "nginx/nginx"
      regexp = "^release\-\\d+\.\\d+\.\\d+$"
      GithubTags.new(client).matched_tags(name, regexp).map do |r|
        Internal.new(r.name.gsub(/^release\-/, ""))
      end.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      url = "http://nginx.org/download/nginx-#{ref}.tar.gz"
      Release.new(ref, url, "http://nginx.org/download/nginx-#{ref}.tar.gz.asc", get_sha256(url))
    end
  end
end
