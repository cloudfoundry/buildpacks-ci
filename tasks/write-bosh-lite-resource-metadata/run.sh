#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

pushd new-bosh-lite-resource
  echo "$DEPLOYMENT_NAME" >> name
  touch metadata
popd
