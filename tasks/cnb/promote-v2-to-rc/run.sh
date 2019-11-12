#!/usr/bin/env bash

set -exo pipefail

mv candidate/*.zip "release-candidate/${LANGUAGE}-buildpack-v$(cat version/version).zip"
