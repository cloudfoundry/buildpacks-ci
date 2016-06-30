#!/bin/bash -l

set -ex

pushd binary-builder

ls spec/**/*_spec.rb | split -l $(expr `ls spec/**/*_spec.rb | wc -l` / $TOTAL_GROUPS)
specs=$(cat $(ls x* | sed -n "$CURRENT_GROUP p"))

gem install bundler --no-ri --no-rdoc
if [ "${RUBYGEM_MIRROR}" != "none" ]
then
    bundle config mirror.https://rubygems.org ${RUBYGEM_MIRROR}
fi
bundle install -j4
bundle exec rspec $specs
popd
