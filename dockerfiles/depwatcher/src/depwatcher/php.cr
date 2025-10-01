require "./base"
require "./semver"
require "xml"
require "http/request"

module Depwatcher
  class Php < Base
    class Release
      include JSON::Serializable
      
      property ref : String
      property url : String
      property sha256 : String
      
      def initialize(@ref : String, @url : String, @sha256 : String)
      end
    end

    def check(version_filter : String? = nil) : Array(Internal)
      if version_filter.nil?
        # When no version_filter is provided, use php.watch to get the latest supported version
        version_filter = get_latest_supported_version()
      end

      version_parts = version_filter.split('.')
      if version_parts.size < 2
        raise "version_filter must be in format 'major.minor', got: #{version_filter}"
      end
      
      major, minor = version_parts.first(2)
      
      # Try to get releases from php.watch first (most reliable and up-to-date)
      phpwatch_versions = get_phpwatch_releases(major, minor)
      if !phpwatch_versions.empty?
        return phpwatch_versions.uniq { |i| i.ref }.sort_by { |i| Semver.new(i.ref) }
      end
      
      # Fallback to PHP.net HTML scraping if php.watch is unavailable
      all_versions = old_versions()
      filtered_versions = all_versions.select do |v|
        v_parts = v.ref.split('.')
        v_parts.size >= 2 && v_parts[0] == major && v_parts[1] == minor
      end

      filtered_versions.uniq { |i| i.ref }.sort_by { |i| Semver.new(i.ref) }
    end

    def in(ref : String) : Release
      url = "https://php.net/distributions/php-#{ref}.tar.gz"
      
      # Try to get SHA256 from JSON API first, fallback to computing it
      major, minor = ref.split('.').first(2)
      param = %q(.[$ref].source[] | select(.filename == ("php-\($ref).tar.gz")) | .sha256)
      cmd = "curl -fsSL 'https://www.php.net/releases/index.php?json&version=#{major}.#{minor}&max=1000' | jq -er --arg ref '#{ref}' '#{param}'"

      output = IO::Memory.new
      err = IO::Memory.new
      status = Process.run("bash", ["-lc", cmd], output: output, error: err)
      
      if status.success? && !output.to_s.strip.empty?
        sha256 = output.to_s.strip
      else
        # Fallback: compute SHA256 by downloading the file
        sha256 = get_sha256(url)
      end
      
      Release.new(ref, url, sha256)
    end

    def get_phpwatch_releases(major : String, minor : String) : Array(Internal)
      # Get specific patch releases from php.watch XML feed (more reliable than HTML scraping)
      cmd = "curl -fsSL 'https://php.watch/versions/#{major}.#{minor}/releases.xml'"
      output = IO::Memory.new
      err = IO::Memory.new
      status = Process.run("bash", ["-lc", cmd], output: output, error: err)
      
      if status.success? && !output.to_s.strip.empty?
        # Parse XML and extract release versions, excluding QA releases (alpha, beta, RC)
        xml_content = output.to_s.strip
        versions = Array(Internal).new
        
        # Extract versions from XML entries, filtering out QA releases
        extract_cmd = %q(echo '#{xml_content}' | grep -E '<title>PHP [0-9]+\.[0-9]+\.[0-9]+</title>' | grep -v 'alpha\|beta\|RC' | sed -E 's/.*<title>PHP ([0-9]+\.[0-9]+\.[0-9]+)<\/title>.*/\1/')
        extract_output = IO::Memory.new
        extract_err = IO::Memory.new
        extract_status = Process.run("bash", ["-lc", extract_cmd], output: extract_output, error: extract_err)
        
        if extract_status.success? && !extract_output.to_s.strip.empty?
          versions = extract_output.to_s.strip.split('\n').map { |v| Internal.new(v.strip) }
          return versions.reject { |v| v.ref.empty? }
        end
      end
      
      # Fallback to HTML scraping if XML parsing fails
      html_cmd = "curl -fsSL 'https://php.watch/versions/#{major}.#{minor}/releases' | grep -oE 'PHP #{major}\\.#{minor}\\.[0-9]+' | sed 's/PHP //g'"
      html_output = IO::Memory.new
      html_err = IO::Memory.new
      html_status = Process.run("bash", ["-lc", html_cmd], output: html_output, error: html_err)
      
      if html_status.success? && !html_output.to_s.strip.empty?
        versions = html_output.to_s.strip.split('\n').map { |v| Internal.new(v.strip) }
        return versions.reject { |v| v.ref.empty? }
      else
        return Array(Internal).new
      end
    end

    def get_latest_supported_version() : String
      # Use php.watch API to get the latest supported PHP version
      cmd = "curl -fsSL 'https://php.watch/api/v1/versions/latest' | jq -er '.data | keys[0] as $version_id | .[$version_id].name'"
      output = IO::Memory.new
      err = IO::Memory.new
      status = Process.run("bash", ["-lc", cmd], output: output, error: err)
      
      if status.success?
        return output.to_s.strip
      else
        # Fallback to HTML scraping approach if php.watch is unavailable
        all_versions = old_versions().uniq { |i| i.ref }.sort_by { |i| Semver.new(i.ref) }
        if all_versions.empty?
          raise "Unable to determine latest PHP version from any source"
        end
        
        latest_version = all_versions.last
        latest_major = latest_version.ref.split('.')[0]
        latest_minor = latest_version.ref.split('.')[1]
        return "#{latest_major}.#{latest_minor}"
      end
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
