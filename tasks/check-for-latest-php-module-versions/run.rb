#!/usr/bin/env ruby
require 'json'
require 'nokogiri'
require 'open-uri'
require 'yaml'
require_relative '../../lib/tracker-client'

def current_pecl_version(name)
  doc = Nokogiri::XML(open("https://pecl.php.net/feeds/pkg_#{name}.rss")) rescue nil 
  return 'Unkown' unless doc
  doc.remove_namespaces!
  versions = doc.xpath('//item/title').map do |li|
    li.text.gsub(/^#{name} /i, '')
  end.reject do |v|
    Gem::Version.new(v).prerelease? rescue false
  end.sort_by do |v|
    Gem::Version.new(v) rescue v
  end
  versions.last
end

def current_github_version(url)
  repo = url.match(%r{^https://github.com/(.*)/releases$})[1]
  data = JSON.parse(open("https://api.github.com/repos/#{repo}/releases").read)
  data.reject do |d|
    d['prerelease'] || d['draft']
  end.map do |d|
    d['name'].gsub(/^\D*v/,'').gsub(/^version\s*/i,'').gsub(/\s*stable$/i,'')
  end.sort_by do |v|
    Gem::Version.new(v) rescue v
  end.last
end

def url_for_type(name, type)
  case type.gsub(/Recipe$/,'')
  when 'PHPProtobufPecl'
    'https://github.com/allegro/php-protobuf/releases'
  when 'SuhosinPecl'
    'https://github.com/sektioneins/suhosin/releases'
  when 'TwigPecl'
    'https://github.com/twigphp/Twig/releases'
  when 'XcachePecl'
    'https://xcache.lighttpd.net/wiki/ReleaseArchive'
  when 'CassandraCppDriver'
    'http://downloads.datastax.com/cpp-driver/ubuntu/14.04/cassandra/'
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

data = {
  'PHP5' => YAML.load(open('buildpacks-ci/tasks/build-binary-new/php-extensions.yml').read),
  'PHP7' => YAML.load(open('buildpacks-ci/tasks/build-binary-new/php7-extensions.yml').read),
  'PHP72' => YAML.load(open('buildpacks-ci/tasks/build-binary-new/php72-extensions.yml').read)
}

Tuple = Struct.new(:name, :klass)
extensions = {}
data.each do |name, hash|
  hash.values.flatten.each do |e|
    key = Tuple.new(e['name'], e['klass'])
    extensions[key] ||= {}
    version = e['version']
    version = nil if version.to_s == 'nil'
    extensions[key][name] = version
  end
end

description = <<-DESCRIPTION
Check that the PHP Module versions used in building PHP 5 and PHP 7 are up to date. If there are new, compatible versions, update them and build new PHP binaries.

Reference the PHP5 and PHP7 recipes and module versions used in cooking these recipes in [binary-builder](https://github.com/cloudfoundry/binary-builder)
DESCRIPTION

description += "\n\n" + %w(Name Latest PHP5 PHP7 PHP72).join(' | ') + "\n"
description += '--- | ---' + "\n"
extensions.keys.sort_by(&:name).each do |key|
  name = "#{key.name} (#{key.klass.gsub(/Recipe$/,'')})"
  url = url_for_type(key.name, key.klass)
  latest = current_pecl_version(key.name) if key.klass =~ /PECL/i
  latest = current_github_version(url) if url =~ %r{^https://github.com}
  data = [url ? "[#{name}](#{url})" : name, latest]
  %w(PHP5 PHP7 PHP72).each do |v|
    val = extensions[key][v]
    val = "**#{val}**" if val && val != latest
    data << val
  end
  description += data.join(' | ') + "\n" unless data[2,3].all?(&:nil?)
end

description += <<-DESCRIPTION

If you're updating cassandra modules (including datastax/cpp-driver) please do so in individual commits, then rebuild appropriate php versions, so integration tests can run in CI with only cassandra changes.
This will help isolate the php cassandra module change(s) if the changes cause problems.
DESCRIPTION

puts description

tracker_client = TrackerClient.new(
  ENV.fetch('TRACKER_API_TOKEN'),
  ENV.fetch('TRACKER_PROJECT_ID'),
  ENV.fetch('TRACKER_REQUESTER_ID').to_i
)
tracker_client.post_to_tracker(
  name: 'Build and/or Include new releases: PHP Modules',
  description: description,
  tasks: ['Check each PHP module for updates', 'Rebuild PHP versions if any module updates', 'Update PHP Buildpack with new PHP versions', 'Copy 7.0 Extensions to 7.2 and remove solr and xdebug'],
  labels: %w(maintenance php)
)
