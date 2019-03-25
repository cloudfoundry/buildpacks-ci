#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

pushd git-repo
  go build ./cmd/pack
  tar -zcvf ./release-tgz/$RELEASE_NAME pack
popd
