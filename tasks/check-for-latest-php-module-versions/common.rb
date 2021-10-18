# NOTE: These utilities are used by the scripts in 'scripts/php-modules' and
# by the 'tasks/check-for-latest-php-module-versions' task!

require 'json'
require 'nokogiri'
require 'open-uri'

def url_for_type(name, type)
  case type.gsub(/Recipe$/,'')
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
    'https://github.com/nrk/phpiredis/releases'
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

def current_pecl_version(name)
  doc = Nokogiri::XML(URI.open("https://pecl.php.net/feeds/pkg_#{name}.rss")) rescue nil
  return 'Unknown' unless doc
  doc.remove_namespaces!
  versions = doc.xpath('//item/title').map do |li|
    li.text.gsub(/^#{name} /i, '')
  end.reject do |v|
    Gem::Version.new(v).prerelease? rescue false
  end.sort_by do |v|
    Gem::Version.new(v)
  end
  versions.last
end

def current_github_version(url, token = nil)
  repo = url.match(%r{^https://github.com/(.*)/releases$})[1]
  opts = token ? {:http_basic_authentication => ['token', token]} : {}
  data = JSON.parse(URI.open("https://api.github.com/repos/#{repo}/releases", **opts).read)
  data.reject do |d|
    d['prerelease'] || d['draft']
  end.map do |d|
    d['tag_name'].gsub(/^\D*[v\-]/,'').gsub(/^version\s*/i,'').gsub(/\s*stable$/i,'')
  end.sort_by do |v|
    Gem::Version.new(v)
  end.last
end
