require "./github_releases.cr"

module Depwatcher
  class Icu < GithubReleases
    class GithubRelease
      JSON.mapping(
        tag_name: String,
        draft: Bool,
        prerelease: Bool,
        assets: Array(GithubAsset),
      )

      def ref
        version = tag_name.gsub(/^release-/, "").gsub(/-/, ".")
        if version =~ /^\d+\.\d+$/
          version += ".0"
        end
        version
      end
    end

    def check() : Array(Internal)
      repo = "unicode-org/icu"
      allow_prerelease = false
      super(repo, allow_prerelease)
    end


    def in(ref : String, dir : String) : Release
      repo = "unicode-org/icu"
      ext = "-src.tgz"
      super(repo, ext, ref, dir)
    end

    private def releases(repo : String) : Array(GithubRelease)
      res = client.get("https://api.github.com/repos/#{repo}/releases").body
      Array(GithubRelease).from_json(res)
    end
  end
end
