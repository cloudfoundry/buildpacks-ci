require "./base"

module Depwatcher
  class GithubTags < Base
    class External
      JSON.mapping(
        name: String,
      )
    end

    def check(name : String, regexp : String) : Array(Internal)
      response = client.get "https://api.github.com/repos/#{name}/tags"
      Array(External).from_json(response).select do |r|
        /#{regexp}/.match(r.name)
      end.map do |r|
        Internal.new(r.name)
      end.first(10).reverse
    end
  end
end
