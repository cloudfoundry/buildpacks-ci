#!/usr/bin/env bash

set -e

main() {
  #pushd feller || echo "failed to run feller"; return
  pushd feller
    echo "Creating Release Story"
    go run main.go create-release-story \
      --tracker-project "${TRACKER_PROJECT_ID}" \
      --tracker-token "${TRACKER_API_TOKEN}" \
      --github-repo "${ORG}/${LANGUAGE}-cnb" \
      --github-token "${GITHUB_TOKEN}" 2>&1
    echo "Release Story Created"
  popd
}

main
