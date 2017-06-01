#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

echo "Extracting cf-acceptance-tests from cf-release"

pushd cf-release/src/github.com/cloudfoundry/cf-acceptance-tests/
  git cherry-pick 4731656e061ca14965a4f4fe47ee19bc6eaeeea2 --no-commit
popd

rsync -a cf-release/src/github.com/cloudfoundry/cf-acceptance-tests/ cf-acceptance-tests/
