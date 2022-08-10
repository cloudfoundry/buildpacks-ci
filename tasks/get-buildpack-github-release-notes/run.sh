#!/usr/bin/env bash

set -euo pipefail

if [ -z "${BUILDPACK_REPO}" ]; then
  # e.g. "cloudfoundry/go-buildpack"
  echo "task error: BUILDPACK_REPO not set" >&2
  exit 1
fi

version=$(cat version/version)
if [ -z "${version}" ]; then
  echo "task error: can't read version from version/version" >&2
  exit 1
fi

release_body=$(
  curl "https://api.github.com/repos/${BUILDPACK_REPO}/releases/tags/v${version}" \
    --silent \
    --location \
  | jq -r '.body'
)

if [[ "${release_body}" == "null" ]]; then
  echo "task error: Error retrieving release notes from github.com/${BUILDPACK_REPO}" >&2
  exit 1
fi

echo -e "${release_body}" > release-body/body
