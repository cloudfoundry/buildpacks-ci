#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if [ -z "${REPO_PRIVATE_KEY:-}" ]; then
  echo "task error: REPO_PRIVATE_KEY not set" >&2
  exit 1
fi

# Set up SSH key for git operations
eval "$(ssh-agent -s)"
ssh-add - <<< "$REPO_PRIVATE_KEY"

VERSION=""
if [[ -d "version" ]]; then
    if [[ -f "version/number" ]]; then
        VERSION=$(cat version/number)
    elif [[ -f "version/version" ]]; then
        VERSION=$(cat version/version)
    fi
else
    VERSION=$(cat buildpack/VERSION)
fi

cd buildpack

# Fetch all tags from remote
git fetch --tags

# Check if tag already exists
if git rev-parse "v${VERSION}" >/dev/null 2>&1; then
    echo "ERROR: Tag v${VERSION} already exists in the repository!"
    echo "Please check the following:"
    echo "  1. Does the tag already exist on GitHub?"
    echo "  2. Is the VERSION file in the buildpack up to date?"
    echo "  3. Has the version been bumped correctly?"
    exit 1
fi

echo "Tag v${VERSION} does not exist - proceeding with release"
