#!/bin/bash -l

set -ex

pushd binary-builder
  ls spec/**/*_spec.rb | split -l $(expr `ls spec/**/*_spec.rb | wc -l` / $TOTAL_GROUPS)
  specs=$(cat $(ls x* | sed -n "$CURRENT_GROUP p"))

  gem install bundler --no-ri --no-rdoc
  bundle config mirror.https://rubygems.org ${RUBYGEM_MIRROR}
  bundle install -j4
  
  if [ ${RUN_ORACLE_PHP_TESTS-false} = "true" ]; then
    bundle exec rspec $specs
  else
    bundle exec rspec $specs --tag ~run_oracle_php_tests
  fi
popd
