#! /usr/bin/env bash

git clone https://github.com/geramirez/concourse-filter
pushd concourse-filter
  go build
  export CREDENTIAL_FILTER_WHITELIST=CREDENTIAL_FILTER_WHITELIST,GEM_HOME,TERM,USER,BUNDLE_APP_CONFIG,PATH,RUBY_DOWNLOAD_SHA256,PWD,LANG,RUBY_MAJOR,RUBYGEMS_VERSION,SHLVL,HOME,RUBY_VERSION,BUNDLER_VERSION,OLDPWD
  exec &> >(./concourse-filter)
popd
