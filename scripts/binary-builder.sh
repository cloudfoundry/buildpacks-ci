#!/bin/bash -l

set -ex

pushd binary-builder

ls spec/**/*_spec.rb | split -l $(expr `ls spec/**/*_spec.rb | wc -l` / $TOTAL_GROUPS)
specs=$(cat $(ls x* | sed -n "$CURRENT_GROUP p"))

gem install bundler --no-ri --no-rdoc
bundle install -j4
bundle exec rspec $specs
popd
