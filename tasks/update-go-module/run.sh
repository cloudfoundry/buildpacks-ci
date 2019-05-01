#!/bin/bash -l

set -euxo pipefail

pushd project
  go get "$MODULE_PATH"
  go mod tidy
  if [[ "$VENDOR" == "true" ]]; then
    go mod vendor
  fi

  git add .

  set +e
    git diff --cached --exit-code
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]
  then
    git commit -m "Update go module $MODULE_PATH"
  else
    echo "$MODULE_PATH is up to date"
  fi
popd