#!/bin/bash
#
# Write a list of tags for docker-image-resource "additional-tags" param
set -o errexit
set -o nounset
set -o pipefail

# If version directory exists, assume the version should be added as a tag
if [[ -d "version" ]]; then
  version="$(cat version/version)"
  echo "$version " > tags/tags
fi

echo "$TAGS" >> tags/tags
