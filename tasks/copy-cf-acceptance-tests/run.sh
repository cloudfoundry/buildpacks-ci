#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

echo "Extracting cf-acceptance-tests from cf-release"

rsync -a cf-release/src/github.com/cloudfoundry/cf-acceptance-tests/ cf-acceptance-tests/
