require "openssl"
require "http/client"
require "./base"
require "./semantic_version"

module Depwatcher
  class GithubReleases < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )

      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    class GithubAsset
      JSON.mapping(
        name: String,
        browser_download_url: String
      )
    end

    class GithubRelease
      JSON.mapping(
        tag_name: String,
        draft: Bool,
        prerelease: Bool,
        assets: Array(GithubAsset),
      )

      def ref
        tag_name.gsub(/^v/, "")
      end
    end

    def check(repo : String, allow_prerelease : Bool) : Array(Internal)
      releases(repo).reject do |r|
        (r.prerelease && !allow_prerelease) || r.draft
      end.map do |r|
        Internal.new(r.ref) if r.ref != ""
      end.compact.sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(repo : String, ext : String, ref : String, dir : String) : Release
      github_release = find_github_release(repo, ref)
      asset = github_release.assets.select do |a|
        a.name.ends_with?(ext)
      end
      raise "Could not determine a single url for version" unless asset.size == 1
      sha = download_release(asset.first.browser_download_url, dir)
      Release.new(github_release.ref, asset.first.browser_download_url, sha)
    end

    def in(repo : String, ref : String, dir : String) : Release
      github_release = find_github_release(repo, ref)
      download_url = "https://github.com/#{repo}/archive/#{github_release.tag_name}.tar.gz"
      sha = download_release(download_url, dir)
      Release.new(github_release.ref, download_url, sha)
    end

    private def releases(repo : String) : Array(GithubRelease)
      res = client.get("https://api.github.com/repos/#{repo}/releases").body
      Array(GithubRelease).from_json(res)
    end

    def find_github_release(repo : String, ref : String)
      github_release = releases(repo).find do |r|
        r.ref == ref
      end
      raise "Could not find release data for version" unless github_release
      github_release
    end

    private def download_release(download_url : String, dest_dir : String) : String
      hash = OpenSSL::Digest.new("SHA256")
      resp = client.get(download_url, HTTP::Headers{"Accept" => "application/octet-stream"})
      hash.update(IO::Memory.new(resp.body))

      File.write(File.join(dest_dir, File.basename(download_url)),resp.body)

      return hash.hexdigest
    end
  end
end
