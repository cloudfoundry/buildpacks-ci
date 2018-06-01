require "./base"
require "./semantic_version"

module Depwatcher
  class Npm < Base
    class Dist
      JSON.mapping(
        shasum: String,
        tarball: String,
      )
    end
    class Version
      JSON.mapping(
        name: String,
        version: String,
        dist: Dist,
      )
    end
    class External
      JSON.mapping(
        versions: Hash(String, Version),
      )
    end
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha1: String,
      )
      def initialize(@ref, @url, @sha1)
      end
    end

    def check(name : String) : Array(Internal)
      releases(name).map do |_, r|
        Internal.new(r.version)
      end.sort_by { |i| SemanticVersion.new(i.ref) }.last(10)
    end

    def in(name : String, ref : String) : Release
      r = releases(name)[ref]
      Release.new(ref, r.dist.tarball, r.dist.shasum)
    end

    private def releases(name : String) : Hash(String,Version)
      response = client.get("https://registry.npmjs.com/#{name}/").body
      External.from_json(response).versions
    end
  end
end
