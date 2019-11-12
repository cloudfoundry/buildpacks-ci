#!/usr/bin/env bash

set -exo pipefail

# shellcheck disable=SC2086
mv candidate/*.zip "release-candidate/${LANGUAGE}-buildpack-v$(cat version/version).zip"
