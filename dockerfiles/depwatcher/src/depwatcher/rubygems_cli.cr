require "./github_releases.cr"

module Depwatcher
  class RubygemsCli < GithubReleases
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

    def check : Array(Internal)
      repo = "rubygems/rubygems"
      allow_prerelease = false
      releases(repo).reject do |r|
        (r.prerelease && !allow_prerelease) || r.draft || ((r.ref.match /^(?!v).*$/ )|| r.ref.includes?("bundler"))
      end.map do |r|
        Internal.new(r.ref) if r.ref != ""
      end.compact.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String, dir : String) : Release
      repo = "rubygems/rubygems"
      ext = ".tar.gz"
      super(repo, ref, dir)
    end

    private def releases(repo : String) : Array(GithubRelease)
      res = client.get("https://api.github.com/repos/#{repo}/releases").body
      Array(GithubRelease).from_json(res)
    end
  end
end
