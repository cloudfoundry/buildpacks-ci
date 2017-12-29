require "json"
require "http/client"

module Depwatcher
  module GithubTags
    class External
      JSON.mapping(
        name: String,
      )
    end
    class Internal
      JSON.mapping(
        ref: String,
      )
      def initialize(external : External)
        @ref = external.name
      end
    end

    def self.check(name : String, regexp : String) : Array(Internal)
      response = HTTP::Client.get "https://api.github.com/repos/#{name}/tags"
      raise "Could not download tags data from github: code #{response.status_code}" unless response.status_code == 200
      Array(External).from_json(response.body).select do |r|
        /#{regexp}/.match(r.name)
      end.map do |r|
        Internal.new(r)
      end.first(10).reverse
    end
  end
end
