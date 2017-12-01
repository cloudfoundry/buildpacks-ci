#!/usr/bin/env ruby
# encoding: utf-8

require 'yaml'

buildpacks_ci_dir = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))
require "#{buildpacks_ci_dir}/lib/tracker-client"

name = 'Build and/or Include new releases: PHP Modules'
description = <<-DESCRIPTION
Check that the PHP Module versions used in building PHP 5 and PHP 7 are up to date. If there are new, compatible versions, update them and build new PHP binaries.

Reference the PHP5 and PHP7 recipes and module versions used in cooking these recipes in [binary-builder](https://github.com/cloudfoundry/binary-builder)
DESCRIPTION
tasks = ['Check each PHP module for updates', 'Rebuild PHP versions if any module updates', 'Update PHP Buildpack with new PHP versions', 'Copy 7.0 Extensions to 7.2 and remove solr and xdebug']
labels = %w(maintenance)

exit if name.empty?
description += "\n\n" unless description.empty?
description += "URL | Latest Version | PHP5 Current | PHP7 Current\n"
description += "--- | ---\n"

php5manifest = YAML.load(open('robots-repo/binary-builds/php-extensions.yml').read)
php5 = Hash[*(php5manifest["extensions"].map {|e|[e["name"],e["version"]]}.flatten)]

php7manifest = YAML.load(open('robots-repo/binary-builds/php7-extensions.yml').read)
php7 = Hash[*(php7manifest["extensions"].map {|e|[e["name"],e["version"]]}.flatten)]

Dir.glob('./*').each do |resource_dir|
  next if resource_dir == './robots-repo'
  begin
    Dir.chdir(resource_dir) do
      url = File.read('url').strip
      version = File.read('version').strip
      php5_current = php7_current = ''
      if url =~ %r{https://pecl.php.net/package/(\S+)}
        php5_current = php5[$1]
        php7_current = php7[$1]
      elsif url =~ %r{https://pecl.php.net/feeds/pkg_(\S+)\.rss}
        php5_current = php5[$1]
        php7_current = php7[$1]
      end
      description += "#{url} | #{version} | #{php5_current} | #{php7_current}\n"
    end
  rescue
    puts "#{resource_dir} is not a new_version_resource"
  end
end

description += <<-DESCRIPTION

If you have updated cassadra modules (including datastax/cpp-driver) please run integration tests locally with `CASSANDRA_HOST` set.

```
docker run -p 0.0.0.0:9042:9042 --detach poklet/cassandra
export CASSANDRA_HOST=[LOCALMACHINE EXTERNAL IP]
CF_PASSWORD=admin BUNDLE_GEMFILE=cf.Gemfile bundle exec buildpack-build --host=local.pcfdev.io cf_spec/integration/deploy_a_php_app_with_cassandra_spec.rb
```
Then stop the above docker cassandra container
DESCRIPTION

puts name
puts ""
puts description

tracker_client = TrackerClient.new(
  ENV.fetch('TRACKER_API_TOKEN'),
  ENV.fetch('TRACKER_PROJECT_ID'),
  ENV.fetch('TRACKER_REQUESTER_ID').to_i
)
tracker_client.post_to_tracker(name: name, description: description, tasks: tasks, labels: labels)
