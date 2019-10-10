#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd buildpack/compile-extensions
  git checkout master
  git pull origin master
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  export BUNDLE_GEMFILE=$PWD/Gemfile
  bundle install --deployment
  bundle cache
  bundle exec rspec
  compile_extensions_head=$(git rev-parse HEAD)
popd

pushd buildpack
  git add compile-extensions/

  set +e
    git diff --cached --exit-code
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]
  then
    git commit -m "Update compile-extensions to $compile_extensions_head"
  else
    echo "compile-extensions in buildpack is up to date"
  fi
popd

rsync -a buildpack/ buildpack-artifacts
