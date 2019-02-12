require "./base"
require "./semantic_version"

module Depwatcher
  class Pypi < Base
    class External
      JSON.mapping(
        releases: Hash(String, Array(ExternalRelease)),
      )
    end

    class ExternalRelease
      JSON.mapping(
        ref: String?,
        url: String,
        digests: Hash(String, String),
        md5_digest: String,
        packagetype: String,
        size: Int64,
      )
    end

    class Release
      JSON.mapping(
        ref: String?,
        url: String,
        md5_digest: String,
        sha256: String
      )
      def initialize(@ref : String, @url : String, @md5_digest : String, @sha256 : String)
      end
    end


    def check(name : String) : Array(Internal)
      releases(name).map do |version, _|
        Internal.new(version)
      end.sort_by { |i| SemanticVersion.new(i.ref) }.last(10)
    end

    def in(name : String, ref : String) : Release
      release = releases(name)[ref].select do |r|
        r.packagetype == "sdist"
      end.sort_by do |r|
        r.size
      end.first
      release.ref = ref
      Release.new(ref, release.url, release.md5_digest, release.digests["sha256"])
    end

    private def releases(name : String) : Hash(String, Array(ExternalRelease))
      response = client.get("https://pypi.org/pypi/#{name}/json").body
      External.from_json(response).releases
        .select do |v|
          semver = SemanticVersion.new(v)
          keep = semver.is_final_release?
          if name == "pip" && semver.major > 9
            keep = false
          end
          keep
        end
    end
  end
end
