#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

set -x

cp extra-blob/"${LANGUAGE}"-buildpack*.zip blob/
