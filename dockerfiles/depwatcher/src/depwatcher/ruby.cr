require "./base"
require "./github_tags"
require "xml"
require "yaml"

module Depwatcher
  class Ruby < Base
    class GithubRelease
      YAML.mapping(
        version: String,
        url: Hash(String, String)?,
        sha256: Hash(String, String)?,
      )
    end

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
      end.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release | Nil
      result = releaseFromGithub(ref)
      if result == nil
        result = releaseFromIndex(ref)
      end
      result
    end

    private def releaseFromGithub(ref : String) : Release | Nil
      result = nil
      response = client.get("https://raw.githubusercontent.com/ruby/www.ruby-lang.org/master/_data/releases.yml").body
      versions = Array(GithubRelease).from_yaml(response)

      versions.each do |v|
        version = v.version
        url = !v.url.nil? ? v.url.not_nil!["gz"] : ""
        sha = !v.sha256.nil? ? v.sha256.not_nil!["gz"] : ""
        newRelease = Release.new(version, url, sha)

        if ref == version
          if url != "" && sha != ""
            result = newRelease
          end
          break
        end
      end
      result
    end

    private def releaseFromIndex(ref : String) : Release | Nil
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
