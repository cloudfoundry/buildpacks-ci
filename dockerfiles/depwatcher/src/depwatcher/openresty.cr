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
      )
      def initialize(@ref : String, @url : String, @pgp : String)
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
      Release.new(ref, "http://openresty.org/download/openresty-#{ref}.tar.gz", "http://openresty.org/download/openresty-#{ref}.tar.gz.asc")
    end
  end
end