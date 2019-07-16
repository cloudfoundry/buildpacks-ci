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
        sha256: String
      )

      def initialize(
        @ref : String,
        @url : String,
        @git_commit_sha : String,
        @sha256 : String
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

    def in(ref : String, tag_regex : String) : DotnetRelease | Nil
      tag = dotnet_tags(tag_regex)
        .select { |t| t.name == ref }
        .first?
      if tag.nil?
        return tag
      end
      url = "https://github.com/dotnet/cli/archive/#{tag.commit}.tar.gz"
      DotnetRelease.new(tag.name, "https://github.com/dotnet/cli", tag.commit, get_sha256(url))
    end

    private def dotnet_tags(tag_regex : String) : Array(External)
      GithubTags.new(client).matched_tags("dotnet/cli", tag_regex)
        .map do |t|
          m = t.name.match(/\d+.\d+.\d+-preview\d+/)
          if !m.nil?
            External.new(m[0], t.commit.sha)
          else
            m = t.name.match(/\d+\.\d+\.\d+/)
            if !m.nil?
                External.new(m[0], t.commit.sha)
            end
          end
        end.compact.uniq { |m| m.name}
    end
  end
end
