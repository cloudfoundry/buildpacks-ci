#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail
set -x

rsync -a buildpack/ updated-buildpack/

pushd updated-buildpack
  git submodule update --init --remote
popd

pushd updated-buildpack/scripts
  submodule_commit="$(git log --format=%B -n 1 HEAD | head -n 1)"
popd

pushd updated-buildpack
  git add .

  set +e
    git diff --cached --exit-code
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]

  then
    git commit -m "$(cat <<-EOF
Update scripts submodule

- $submodule_commit
EOF
)"
  else
    echo "scripts are already up to date"
  fi
popd
