require "./base"
require "./semantic_version"

module Depwatcher
  class Pypi < Base
    class External
      JSON.mapping(
        releases: Hash(String, Array(Release)),
      )
    end
    class Release
      JSON.mapping(
        ref: String?,
        url: String,
        md5_digest: String,
        packagetype: String,
        size: Int64,
      )
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
      release
    end

    private def releases(name : String) : Hash(String, Array(Release))
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
