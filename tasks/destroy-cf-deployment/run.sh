#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

bosh2 -n delete-deployment -d "${DEPLOYMENT_NAME}"
