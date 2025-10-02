require "./base"
require "./github_tags"
require "xml"

module Depwatcher
  class Openresty < Base
    class Release
      include JSON::Serializable

      property ref : String
      property url : String
      property pgp : String
      property sha256 : String
      def initialize(@ref : String, @url : String, @pgp : String, @sha256 : String)
      end
    end

    def check() : Array(Internal)
      name = "openresty/openresty"
      regexp = "\\d+\.\\d+\.\\d+\.\\d+$"
      GithubTags.new(client).matched_tags(name, regexp).map do |r|
        Internal.new(r.name.gsub(/^v/, ""))
      end.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      url = "http://openresty.org/download/openresty-#{ref}.tar.gz"
      Release.new(ref, url, "http://openresty.org/download/openresty-#{ref}.tar.gz.asc", get_sha256(url))
    end
  end
end
