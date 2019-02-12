require "./base"
require "./github_tags"
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
      regexp = "^v\\d+\.\\d+\.\\d+\.\\d+$"
      GithubTags.new(client).matched_tags(name, regexp).map do |r|
        Internal.new(r.name.gsub(/^v/, ""))
      end.sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(ref : String) : Release
      url = "http://openresty.org/download/openresty-#{ref}.tar.gz"
      Release.new(ref, url, "http://openresty.org/download/openresty-#{ref}.tar.gz.asc", get_sha256(url))
    end
  end
end