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
        tag_name.gsub(/^release-/, "").gsub(/-/, ".")
      end
    end

    def check() : Array(Internal)
      repo = "unicode-org/icu"
      allow_prerelease = false
      super(repo, allow_prerelease)
    end


    def in(ref : String, dir : String) : Release
      repo = "unicode-org/icu"
      ext = "-Ubuntu18.04-x64.tgz"
      super(repo, ext, ref, dir)
    end

    private def releases(repo : String) : Array(GithubRelease)
      res = client.get("https://api.github.com/repos/#{repo}/releases").body
      Array(GithubRelease).from_json(res)
    end
  end
end
