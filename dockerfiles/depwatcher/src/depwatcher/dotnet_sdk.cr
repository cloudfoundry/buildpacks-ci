require "./base"
require "./semantic_version"
require "./github_releases"
require "./github_tags"

module Depwatcher
  class DotnetSdk < Base
    class DotnetRelease
      JSON.mapping(
        ref: String,
        url: String,
        git_commit_sha: String,
      )

      def initialize(
        @ref : String,
        @url : String,
        @git_commit_sha : String
      )
      end
    end

    class External
      JSON.mapping(
        name: String,
        commit: String
      )

      def initialize(
        @name : String,
        @commit : String
      )
      end
    end

    def check(tag_regex : String) : Array(Internal)
      dotnet_tags(tag_regex)
        .map { |t| Internal.new(t.name) }
        .sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(ref : String, tag_regex : String) : DotnetRelease
      tag = dotnet_tags(tag_regex)
        .select { |t| t.name == ref }
        .first
      DotnetRelease.new(tag.name, "https://github.com/dotnet/cli", tag.commit)
    end

    private def dotnet_tags(tag_regex : String) : Array(External)
      GithubTags.new(client).matched_tags("dotnet/cli", tag_regex)
        .map do |t|
          m = t.name.match(/\d+\.\d+\.\d+/)
          if !m.nil?
            External.new(m[0], t.commit.sha)
          end
        end.compact
    end
  end
end
