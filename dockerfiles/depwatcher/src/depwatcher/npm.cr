require "./base"
require "./semver"

module Depwatcher
  class Npm < Base
    class Dist
      include JSON::Serializable

      property shasum : String
      property tarball : String
    end
    class Version
      include JSON::Serializable

      property name : String
      property version : String
      property dist : Dist
    end
    class External
      include JSON::Serializable

      property versions : Hash(String, Version)
    end
    class Release
      include JSON::Serializable

      property ref : String
      property url : String
      property sha1 : String
      def initialize(@ref, @url, @sha1)
      end
    end

    def check(name : String) : Array(Internal)
      releases(name).map do |_, r|
        Internal.new(r.version)
      end.sort_by { |i| Semver.new(i.ref) }.last(10)
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
