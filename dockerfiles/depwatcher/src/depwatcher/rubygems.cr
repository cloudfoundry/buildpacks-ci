require "./base"

module Depwatcher
  class Rubygems < Base
    class External
      JSON.mapping(
        number: String,
        sha: String,
        prerelease: Bool,
      )
    end
    class Release
      JSON.mapping(
        ref: String,
        sha256: String,
      )
      def initialize(external : External)
        @ref = external.number
        @sha256 = external.sha
      end
    end

    def check(name : String) : Array(Internal)
      releases(name).reject do |r|
        r.prerelease
      end.map do |r|
        Internal.new(r.number)
      end.first(10).reverse
    end

    def in(name : String, ref : String) : Release
      Release.new(release(name, ref))
    end

    private def releases(name : String) : Array(External)
      response = client.get("https://rubygems.org/api/v1/versions/#{name}.json").body
      Array(External).from_json(response)
    end

    private def release(name : String, version : String) : External
      response = client.get("https://rubygems.org/api/v2/rubygems/#{name}/versions/#{version}.json").body
      External.from_json(response)
    end
  end
end
