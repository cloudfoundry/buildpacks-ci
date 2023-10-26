#!/usr/bin/env bash

set -euo pipefail

if [ -z "${BUILDPACK_REPO}" ]; then
  # e.g. "cloudfoundry/go-buildpack"
  echo "task error: BUILDPACK_REPO not set" >&2
  exit 1
fi

if [ -z "${OFFLINE_RELEASE}" ]; then
  # e.g. "pivotal-cf/go-offline-buildpack-release"
  echo "task error: OFFLINE_RELEASE not set" >&2
  exit 1
fi

if [ -z "${GITHUB_ACCESS_TOKEN}" ]; then
  echo "task error: GITHUB_ACCESS_TOKEN not set" >&2
  exit 1
fi

pushd buildpack

release_body=''

while IFS= read -r line
do
  version="${line/v/}"

  offline_release_body=$(
     curl "https://api.github.com/repos/${OFFLINE_RELEASE}/releases/tags/${version}" \
       --silent \
       --location \
       --header "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
     | jq -r '.body'
   )

  if [[ "${offline_release_body}" == "null" ]]; then
    release_body+=$(
      curl "https://api.github.com/repos/${BUILDPACK_REPO}/releases/tags/v${version}" \
        --silent \
        --location \
        --header "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
      | jq -r '.body' | sed '/^Packaged binaries:$/,$d'
    )

    if [[ "${release_body}" == "null" ]]; then
      echo "task error: Error retrieving release notes from github.com/${BUILDPACK_REPO}" >&2
      exit 1
    fi

  else
     break
  fi

done < <(git tag -l --sort=-version:refname "v*")

popd

echo -e "${release_body}" > release-body/body
