require "./base"
require "./semantic_version"

module Depwatcher
  class GithubTags < Base
    class Tag
      JSON.mapping(
        ref: String,
        url: String,
        git_commit_sha: String,
      )
      def initialize(@ref : String, @url : String, @git_commit_sha : String)
      end
    end

    class External
      JSON.mapping(
        name: String,
        commit: Commit,
      )
    end

    class Commit
      JSON.mapping(
            sha: String,
      )
    end

    def check(repo : String, regexp : String) : Array(Internal)
      matched_tags(repo, regexp).sort_by { |i| SemanticVersion.new(i.ref) }
    end

    def in(repo : String, ref : String) : Tag
      t = tags(repo).find do |t|
        t.name == ref
      end
      raise "Could not find data for version #{ref}" unless t
      Tag.new(t.name, "https://github.com/#{repo}", t.commit.sha)
    end

    def matched_tags(repo : String, regexp : String) : Array(Internal)
      tags(repo).select do |t|
        /#{regexp}/.match(t.name)
      end.map do |t|
        Internal.new(t.name)
      end
    end


    private def tags(repo : String) : Array(External)
      res = client.get("https://api.github.com/repos/#{repo}/tags").body
      Array(External).from_json(res)
    end
  end
end
