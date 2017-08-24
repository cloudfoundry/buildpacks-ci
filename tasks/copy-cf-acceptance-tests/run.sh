#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

if [ ! -z "$BRANCH" ]; then
  echo Checking out branch "$BRANCH"
  pushd cf-release/src/github.com/cloudfoundry/cf-acceptance-tests
    git fetch
    git checkout "$BRANCH"
  popd
fi

echo "Extracting cf-acceptance-tests from cf-release"
rsync -a cf-release/src/github.com/cloudfoundry/cf-acceptance-tests/ cf-acceptance-tests/
