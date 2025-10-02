require "./base"
require "./semver"
require "./github_tags"
require "xml"
require "http/request"

module Depwatcher
  class Httpd < Base
    class Release
      include JSON::Serializable

      property ref : String
      property url : String
      property sha256 : String

      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check : Array(Internal)
      repo = "apache/httpd"
      regexp = "^\\d+\\.\\d+\\.\\d+$"
      GithubTags.new(client).matched_tags(repo, regexp).map do |r|
        Internal.new(r.name)
      end.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      sha_response = nil
      max_retries = 3
      retries = 0

      while retries < max_retries
        sha_response = HTTP::Client.get("https://archive.apache.org/dist/httpd/httpd-#{ref}.tar.bz2.sha256")
        if sha_response.status_code != 200
          retries += 1
          sleep(5.seconds)
        else
          break
        end
      end

      unless sha_response.nil?
        sha256 = sha_response.body.split(" ")[0]
        Release.new(ref, "https://dlcdn.apache.org/httpd/httpd-#{ref}.tar.bz2", sha256)
      else
        raise "Could not retreive the page after #{max_retries} attempts"
      end
    end
  end
end
