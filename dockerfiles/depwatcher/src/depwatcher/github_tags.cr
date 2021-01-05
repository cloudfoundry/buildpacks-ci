require "./base"
require "./semver"

module Depwatcher
  class GithubTags < Base
    class Tag
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
        commit: Commit
      )
    end

    class Commit
      JSON.mapping(
        sha: String
      )
    end

    def check(repo : String, tag_regex : String) : Array(Internal)
      matched_tags(repo, tag_regex)
      .map { |t| Internal.new(t.name) }
      .sort_by { |i| Semver.new(i.ref) }
    end

    def in(repo : String, ref : String) : Tag
      t = tags(repo).find { |t| t.name == ref }
      raise "Could not find data for version #{ref}" unless t

      url = "https://github.com/#{repo}/archive/#{t.commit.sha}.tar.gz"
      Tag.new(t.name, url, t.commit.sha, get_sha256(url))
    end

    def matched_tags(repo : String, tag_regex : String) : Array(External)
      tags(repo)
        .select { |t| /#{tag_regex}/.match(t.name) }
    end

    private def tags(repo : String) : Array(External)
      res = client.get("https://api.github.com/repos/#{repo}/tags?per_page=1000").body
      Array(External).from_json(res)
    end
  end
end
