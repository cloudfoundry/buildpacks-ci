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
      )
      def initialize(@ref : String, @url : String, @pgp : String)
      end
    end

    def check() : Array(Internal)
      name = "nginx/nginx"
      regexp = "^release\-\\d+\.\\d+\.\\d+$"
      GithubTags.new(client).check(name, regexp).map do |r|
        r.ref = r.ref.gsub(/^release\-/, "")
        r
      end
    end

    def in(ref : String) : Release
      Release.new(ref, "http://nginx.org/download/nginx-#{ref}.tar.gz", "http://nginx.org/download/nginx-#{ref}.tar.gz.asc")
    end
  end
end
