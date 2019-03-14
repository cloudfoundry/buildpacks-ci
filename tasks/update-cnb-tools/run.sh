#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

rm -rf buildpack/scripts
cp -r cnb-tools-git buildpack/scripts

pushd buildpack
  rm -rf .git/hooks/*
  git add .

  set +e
    git diff --cached --exit-code
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]
  then
    git commit -m "Update CNB tools" --no-verify
  else
    echo "CNB tools are up to date"
  fi
popd

rsync -a buildpack/ buildpack-artifacts
