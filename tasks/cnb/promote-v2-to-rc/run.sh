#!/usr/bin/env bash

set -exo pipefail

mv candidate/*.zip "v2-release-candidate/${LANGUAGE}-v$(cat version/version).tgz"
