require "./base"
require "./semver"
require "./github_tags"
require "xml"
require "http/request"

module Depwatcher
  class Httpd < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check() : Array(Internal)
      repo = "apache/httpd"
      regexp = "^\\d+\.\\d+\.\\d+$"
      GithubTags.new(client).matched_tags(repo, regexp).map do |r|
        Internal.new(r.name)
      end.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      sha_response = HTTP::Client.get("https://archive.apache.org/dist/httpd/httpd-#{ref}.tar.bz2.sha256").body
      sha256 = sha_response.split(" ")[0]
      Release.new(ref, "https://dlcdn.apache.org/httpd/httpd-#{ref}.tar.bz2", sha256)
    end
  end
end
