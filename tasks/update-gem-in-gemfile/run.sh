#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

set -x

GEM_VERSION=$(cat gem/version)
NEW_VERSION_LINE="gem '$GEM_NAME', git: '$GEM_GIT_REPOSITORY', tag: 'v$GEM_VERSION'"

pushd repo-with-gemfile
  sed -i "s|^gem '$GEM_NAME'.*$|$NEW_VERSION_LINE|" "$GEMFILE_NAME"
  if [ ! -z "$RUBYGEM_MIRROR" ]; then
    bundle config mirror.https://rubygems.org "${RUBYGEM_MIRROR}"
  fi
  BUNDLE_GEMFILE="$GEMFILE_NAME" bundle install
  git add "$GEMFILE_NAME" "$GEMFILE_NAME.lock"

  set +e
    git diff --cached --exit-code
    no_changes=$?
  set -e

  if [ $no_changes -ne 0 ]
  then
    git commit -m "Update $GEM_NAME to $GEM_VERSION"
  else
    echo "$GEM_NAME in $GEMFILE_NAME is up to date"
  fi
popd

rsync -a repo-with-gemfile/ repo-with-gemfile-artifacts
