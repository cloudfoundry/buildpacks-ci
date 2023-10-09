# NOTE: These utilities are used by the scripts in 'scripts/php-modules' and
# by the 'tasks/check-for-latest-php-module-versions' task!

require 'json'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'rubygems/version'

# Get the release URL for a module
def url_for_type(name, type)
  case type.gsub(/Recipe$/, '')
  when 'LibSodium'
    'https://github.com/jedisct1/libsodium/releases'
  when 'PHPProtobufPecl'
    'https://github.com/allegro/php-protobuf/releases'
  when 'SuhosinPecl'
    'https://github.com/sektioneins/suhosin/releases'
  when 'TwigPecl'
    'https://github.com/twigphp/Twig/releases'
  when 'XcachePecl'
    'https://xcache.lighttpd.net/wiki/ReleaseArchive'
  when 'CassandraCppDriver'
    'http://downloads.datastax.com/cpp-driver/ubuntu/18.04/cassandra/'
  when 'Hiredis'
    'https://github.com/redis/hiredis/releases'
  when 'IonCube'
    'http://www.ioncube.com/loaders.php'
  when 'Libmemcached'
    'https://launchpad.net/libmemcached/+download'
  when 'LibRdKafka'
    'https://github.com/edenhill/librdkafka/releases'
  when 'Lua'
    'http://www.lua.org/ftp/'
  when 'Phalcon'
    'https://github.com/phalcon/cphalcon/releases'
  when 'PHPIRedis'
    'https://github.com/nrk/phpiredis/tags'
  when 'RabbitMQ'
    'https://github.com/alanxz/rabbitmq-c/releases'
  when 'TidewaysXhprof'
    'https://github.com/tideways/php-xhprof-extension/releases'
  when 'UnixOdbc'
    'http://www.unixodbc.org/'
  when /PECL/i
    "https://pecl.php.net/package/#{name}"
  end
end

# Get the latest version of a PECL module
def current_pecl_version(name)
  rss_url = "https://pecl.php.net/feeds/pkg_#{name}.rss"
  doc = Nokogiri::XML(URI.open(rss_url)) rescue nil
  return 'Unknown' unless doc

  doc.remove_namespaces!
  versions = doc.xpath('//item/title').map { |li| li.text.gsub(/^#{name} /i, '') }
  versions.reject! { |v| Gem::Version.new(v).prerelease? rescue false }
  versions.sort_by! { |v| Gem::Version.new(v) }
  versions.last
end

# Get the latest version of a module from GitHub releases or tags
def current_github_version(url, type = 'release', token = nil)
  repo = url.match(%r{^https://github.com/(.*)/(releases|tags)$})[1]
  opts = token ? { http_basic_authentication: ['token', token] } : {}
  releases_or_tags = JSON.parse(URI.open("https://api.github.com/repos/#{repo}/#{type}s", **opts).read)

  if type == 'release'
    items = releases_or_tags.reject { |d| d['prerelease'] || d['draft'] }
    versions = items.map { |d| d['tag_name'].gsub(/^\D*[v\-]/, '').gsub(/^version\s*/i, '').gsub(/\s*stable$/i, '').gsub(/\s*-RELEASE$/i, '') }
  elsif type == 'tag'
    versions = releases_or_tags.map { |d| d['name'].gsub(/^\D*[v\-]/, '').gsub(/^version\s*/i, '').gsub(/\s*stable$/i, '').gsub(/\s*-RELEASE$/i, '') }
  else
    raise ArgumentError, "Invalid 'type' parameter. Supported values are 'release' and 'tag'."
  end

  latest_version = versions.map { |v| Gem::Version.new(v) }.max
  latest_version.to_s
end

# Get the latest IonCube version
def current_ioncube_version(url)
  doc = Nokogiri::HTML(URI.open(url))
  table = doc.at_css('.loaders-rc-table')
  valid_versions = []

  table.css('tr td:nth-child(2)').map(&:text).reject(&:empty?).each do |version|
    cleaned_version = version.strip
    valid_versions << cleaned_version if cleaned_version.match(/^\d+\.\d+\.\d+$/)
  end

  sorted_versions = valid_versions.map { |v| Gem::Version.new(v) }.sort
  latest_version = sorted_versions.last
  latest_version.to_s
end

# Get the latest Lua version
def current_lua_version(url)
  doc = Nokogiri::HTML(URI.open(url))
  table = doc.at('table')

  versions = []

  table.css('tr').drop(1).each do |row|
    filename = row.at('td.name a').text
    match = filename.match(/lua-(\d+\.\d+\.\d+)/)

    versions << match[1] if match
  end

  sorted_versions = versions.map { |v| Gem::Version.new(v) }.sort
  latest_version = sorted_versions.last
  latest_version.to_s
end