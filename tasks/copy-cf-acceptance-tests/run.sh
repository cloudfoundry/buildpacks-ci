#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

echo "Extracting cf-acceptance-tests from cf-release"

pushd cf-release/src/github.com/cloudfoundry/cf-acceptance-tests/
	git cherry-pick cb1a27ee39f4e91fd6fe394314bd0808b2a53f5e --no-commit
popd

rsync -a cf-release/src/github.com/cloudfoundry/cf-acceptance-tests/ cf-acceptance-tests/
