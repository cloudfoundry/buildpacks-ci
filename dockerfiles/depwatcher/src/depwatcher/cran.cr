require "./base"
require "./semantic_version"
require "xml"

module Depwatcher
  class CRAN < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
      )

      def initialize(@ref : String, @url : String)
      end
    end

    def check(name : String) : Array(Internal)
      response = client.get("https://cran.cnr.berkeley.edu/web/packages/#{name}/index.html").body
      doc = XML.parse_html(response)

      version = doc.xpath("//td/text()[normalize-space(.) = \"Version:\"]//parent::td/following-sibling::td/text()[normalize-space(.)]")
      raise "Could not parse #{name} website" unless version.is_a?(XML::NodeSet)

      version = version.to_s.gsub("-", ".")
      return [Internal.new(version)]
    end

    def in(name : String, ref : String) : Release
      semver = ref.split(".")
      major = semver[0]
      minor = semver[1]
      patch = ""
      if semver.size > 2
        patch = "#{(name == "Rserve") ? "-" : "."}#{semver[2]}"
      end
      Release.new(ref, "https://cran.cnr.berkeley.edu/src/contrib/#{name}_#{major}.#{minor}#{patch}.tar.gz")
    end
  end
end
