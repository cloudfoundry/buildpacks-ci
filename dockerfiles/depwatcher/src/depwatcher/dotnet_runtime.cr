require "./base"
require "./semantic_version"

module Depwatcher
  class DotnetRuntime < Base
    class External
      JSON.mapping(
        name: String,
      )
      def initialize(@name : String)
      end
    end

    def check() : Array(Internal)
      builds.map{|b| Internal.new(b.name) }.sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(ref : String) : Internal
      b = builds.find do |b|
        b.name == ref
      end
      raise "Could not find data for version #{ref}" unless b
      Internal.new(b.name)
    end

    private def builds() : Array(External)
      res = client.get("https://api.github.com/repos/cloudfoundry/public-buildpacks-ci-robots/contents/binary-builds-new/dotnet-runtime").body
      Array(External).from_json(res).map{ |b| External.new(b.name.gsub(/\.json$/, ""))}
    end
  end
end
