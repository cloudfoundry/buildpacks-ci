#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

NEW_PACK_VERSION=$(cat pack/version)
sed "s/PACK_VERSION=\".*\"/PACK_VERSION=\"$NEW_PACK_VERSION\"/g" -i cnb-scripts/install_tools.sh
rsync -a cnb-scripts/ updated-cnb-scripts/

pushd updated-cnb-scripts
  git add .

  set +e
    git diff --cached --exit-code
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]
  then
    git commit -m "Update pack to version $NEW_PACK_VERSION"
  else
    echo "pack is up to date"
  fi
popd
