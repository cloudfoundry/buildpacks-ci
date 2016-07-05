#! /usr/bin/env bash

git clone https://github.com/geramirez/concourse-filter
pushd concourse-filter
  go build
  export CREDENTIAL_FILTER_WHITELIST=`env | cut -d '=' -f 1 | grep -v '^_$' | xargs echo | tr ' ' ','`
  exec &> >(./concourse-filter)
popd
