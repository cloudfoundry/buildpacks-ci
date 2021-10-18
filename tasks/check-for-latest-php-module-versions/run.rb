#!/usr/bin/env ruby

require 'yaml'
require_relative('common.rb')
require_relative '../../lib/tracker-client'
require_relative '../../tasks/build-binary-new/merge-extensions'

base_extensions = BaseExtensions.new('buildpacks-ci/tasks/build-binary-new/php7-base-extensions.yml')
php73_extensions = base_extensions.patch('buildpacks-ci/tasks/build-binary-new/php73-extensions-patch.yml')
php74_extensions = base_extensions.patch('buildpacks-ci/tasks/build-binary-new/php74-extensions-patch.yml')

data = {
  'PHP7.3' => php73_extensions.base_yml,
  'PHP7.4' => php74_extensions.base_yml,
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
Check that the PHP Module versions used in building PHP 7 are up to date. If there are new, compatible versions, update them and build new PHP binaries.

Reference the PHP7 recipes and module versions used in cooking these recipes in [binary-builder](https://github.com/cloudfoundry/binary-builder)
DESCRIPTION

description += "\n\n" + %w(Name Latest PHP7.3 PHP7.4).join(' | ') + "\n"
description += '--- | --- | --- | --- | --- ' + "\n"
extensions.keys.sort_by(&:name).each do |key|
  name = "#{key.name} (#{key.klass.gsub(/Recipe$/,'')})"
  url = url_for_type(key.name, key.klass)
  latest = current_pecl_version(key.name) if key.klass =~ /PECL/i
  latest = current_github_version(url) if url =~ %r{^https://github.com}
  data = [url ? "[#{name}](#{url})" : name, latest]
  %w(PHP7.3 PHP7.4).each do |v|
    val = extensions[key][v]
    val = "**#{val}**" if val && val != latest
    data << val
  end
  description += data.join(' | ') + "\n" unless data[2,3].all?(&:nil?)
end

description += <<-DESCRIPTION

If you're updating cassandra modules (including datastax/cpp-driver) please do so in individual commits, then rebuild appropriate php versions, so integration tests can run in CI with only cassandra changes.
This will help isolate the php cassandra module change(s) if the changes cause problems.

If the release is compatible with all versions update the php7-base-extensions.yml file. Otherwise, 
update the respective patch file. 

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
  tasks: [
    'Check each PHP module for updates and update extension configs (in `buildpacks-ci`)',
    'Rebuild PHP versions if any module updates',
    'Update PHP Buildpack with new PHP versions',
  ],
  labels: %w(maintenance php)
)
