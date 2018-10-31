#!/bin/bash -l
set -o errexit
set -o nounset
set -o pipefail

cd buildpack

# for the PHP buildpack
if [ -e run_tests.sh ]; then
  TMPDIR="$(mktemp -d)"
  export TMPDIR
  pip install -r requirements.txt
fi

./scripts/unit.sh
