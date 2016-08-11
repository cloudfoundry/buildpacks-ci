#!/usr/bin/env bash
set -e

cd buildpack
git tag v`cat VERSION`
export BUNDLE_GEMFILE=cf.Gemfile
bundle config mirror.https://rubygems.org ${RUBYGEM_MIRROR}
bundle install
bundle exec buildpack-packager --uncached
bundle exec buildpack-packager --cached

timestamp=$(date +%s)
ruby <<RUBY
require "fileutils"
Dir.glob("*.zip").map do |filename|
  filename.match(/(.*)_buildpack(-cached)?-v(.*).zip/) do |match|
    language = match[1]
    cached = match[2]
    version = match[3]
    FileUtils.mv(filename, "#{language}_buildpack#{cached}-v#{version}+$timestamp.zip")
  end
end
RUBY

cd ../buildpack-artifacts

mv ../buildpack/*_buildpack-v*.zip .
mv ../buildpack/*_buildpack-cached-v*.zip .

echo md5: "`md5sum *_buildpack-v*.zip`"
echo sha256: "`sha256sum *_buildpack-v*.zip`"
echo md5: "`md5sum *_buildpack-cached-v*.zip`"
echo sha256: "`sha256sum *_buildpack-cached-v*.zip`"
