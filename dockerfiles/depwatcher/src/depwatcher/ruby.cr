require "./base"
require "./github_tags"
require "xml"

module Depwatcher
  class Ruby < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )

      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check : Array(Internal)
      name = "ruby/ruby"
      regexp = "^v\\d+_\\d+_\\d+$"
      GithubTags.new(client).matched_tags(name, regexp).map do |r|
        Internal.new(r.name.gsub("_", ".").gsub(/^v/, ""))
      end.sort_by { |i| SemanticVersion.new(i.ref) }
    end

     def in(ref : String) : Release | Nil
      result = Release.new("","","")
      allReleases = [] of Release
      response = client.get("https://cache.ruby-lang.org/pub/ruby/index.txt").body

      response.each_line do |line|
        releaseArray = [] of String
        line.split { |s| releaseArray << s}
        raise "Could not parse ruby website" unless !releaseArray.empty?
        version = releaseArray[0].lchop("ruby-")
        url = releaseArray[1]
        sha = releaseArray[3]
        newRelease = Release.new(version, url, sha)

        if ref == version && url.ends_with?("tar.gz")
          result = newRelease
        end
      end
      raise ("No release with ref:" + ref + "found") unless !result.url.empty?
      result
    end
  end
end
