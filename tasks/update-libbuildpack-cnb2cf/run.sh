#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail
set -x

pushd cnb2cf
  go get github.com/cloudfoundry/libbuildpack
  rm -rf .git/hooks/*
  git add .

  set +e
    git diff --cached --exit-code -s
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]
  then
    git commit -m "Update libbuildpack" --no-verify
  else
    echo "libbuildpack is up to date"
  fi
popd

echo "WE MADE IT ALL THE WAY HERE"

rsync -a cnb2cf/ cnb2cf-artifacts
