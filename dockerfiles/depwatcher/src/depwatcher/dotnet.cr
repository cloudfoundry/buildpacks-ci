require "./base"
require "./semantic_version"
require "./github_releases"
require "./github_tags"


module Depwatcher
  class Dotnet < Base
    class DotnetRelease
      JSON.mapping(
        ref: String,
        url: String,
        git_commit_sha: String,
      )
      def initialize(@ref : String, @url : String, @git_commit_sha : String)
      end
    end

    def check() : Array(Internal)
      GithubReleases.new(client).check("dotnet/cli")
    end

    def in(ref : String) : DotnetRelease
      release = GithubReleases.new(client).find_github_release("dotnet/cli", ref)
      DotnetRelease.new(release.ref, "https://github.com/dotnet/cli", get_dotnet_release_commit(release.tag_name))
    end

    private def get_dotnet_release_commit(tag : String)
      GithubTags.new(client).in("dotnet/cli", tag).git_commit_sha
    end
  end
end
