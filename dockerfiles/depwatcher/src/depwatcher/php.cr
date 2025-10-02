require "./base"
require "./semver"
require "xml"
require "http/request"

module Depwatcher
  class Php < Base
    class Release
      JSON.mapping(
        ref: String,
        url: String,
        sha256: String,
      )
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check(version_filter : String) : Array(Internal)
      major, minor  = version_filter.split('.').first(2)
      cmd = "curl -fsSL 'https://www.php.net/releases/index.php?json&version=#{major}.#{minor}&max=1000' | jq -er 'keys'"
      output = IO::Memory.new
      err = IO::Memory.new
      status = Process.run("bash", ["-lc", cmd], output: output, error: err)
      raise "command failed: #{err.to_s.strip}" unless status.success?

      retrieved_versions = Array(String).from_json(output.to_s)
      versions = retrieved_versions.map { |v| Internal.new(v) }

      versions += old_versions()
      versions = versions.uniq { |i| i.ref }
      versions.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      major, minor  = ref.split('.').first(2)
      param = %q(.[$ref].source[] | select(.filename == ("php-\($ref).tar.gz")) | .sha256)
      cmd = "curl -fsSL 'https://www.php.net/releases/index.php?json&version=#{major}.#{minor}&max=1000' | jq -er --arg ref '#{ref}' '#{param}'"

      output = IO::Memory.new
      err = IO::Memory.new
      status = Process.run("bash", ["-lc", cmd], output: output, error: err)
      raise "command failed: #{err.to_s.strip}" unless status.success?
      sha256 = output.to_s.strip
      url = "https://php.net/distributions/php-#{ref}.tar.gz"
      Release.new(ref, url, sha256)
    end

    def old_versions() : Array(Internal)
      response = client.get("https://secure.php.net/releases/").body
      doc = XML.parse_html(response)
      php7_versions = doc.xpath_nodes("//h2[starts-with(text(),\"7.\")]").map { |e| Internal.new(e.content) }
      php8_versions = doc.xpath_nodes("//h2[starts-with(text(),\"8.\")]").map { |e| Internal.new(e.content) }
      [php7_versions, php8_versions].flatten
    end
  end
end
