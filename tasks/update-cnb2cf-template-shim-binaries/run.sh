#!/bin/bash -l

set -euo pipefail

version=$(cat s3/version)
mv s3/detect cnb2cf/template/bin/
mv s3/supply cnb2cf/template/bin/
mv s3/finalize cnb2cf/template/bin/
mv s3/release cnb2cf/template/bin/

pushd cnb2cf
  git add .

  set +e
    git diff --cached --exit-code
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]
  then
    git commit -m "Update create template with new shim binaries $version"
  else
    echo "create template is up to date"
  fi
popd