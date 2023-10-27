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

new_version=$(cat version/version)
if [ -z "${new_version}" ]; then
  echo "task error: can't read version from version/version" >&2
  exit 1
fi

pushd buildpack

response=$(
  curl "https://api.github.com/repos/${BUILDPACK_REPO}/releases/tags/v${new_version}" \
        --silent \
        --location \
        --header "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
)

changelog=$( echo "$response" | jq -r '.body' | sed '/^Packaged binaries:$/,$d')
release_body_suffix=$(echo "$response" | jq -r '.body' | sed '1,/^Packaged binaries:$/d')

while IFS= read -r line
do
  if [[ $new_version == "${line/v/}" ]]; then
    continue
  fi

  offline_release_body=$(
     curl "https://api.github.com/repos/${OFFLINE_RELEASE}/releases/tags/${line/v/}" \
       --silent \
       --location \
       --header "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
     | jq -r '.body'
   )

  if [[ "${offline_release_body}" == "null" ]]; then
    missed_changelog=$(
      curl "https://api.github.com/repos/${BUILDPACK_REPO}/releases/tags/${line}" \
        --silent \
        --location \
        --header "Authorization: Bearer ${GITHUB_ACCESS_TOKEN}" \
      | jq -r '.body' | sed '/^Packaged binaries:$/,$d'
    )

    if [[ "${missed_changelog}" == "null" ]]; then
      echo "task error: Error retrieving release notes from github.com/${BUILDPACK_REPO}" >&2
      exit 1
    fi

    changelog+="\n\n$missed_changelog"
  else
     break
  fi
done < <(git tag -l --sort=-version:refname "v*")

release_body="$changelog$release_body_suffix"
popd

echo -e "${release_body}" > release-body/body
