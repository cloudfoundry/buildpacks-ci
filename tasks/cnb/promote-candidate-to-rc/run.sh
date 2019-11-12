#!/usr/bin/env bash

set -exo pipefail

#mv candidate/candidate.zip "release-candidate/nodejs_buildpack-v$(cat version/version).zip"
mv candidate/metacnb-candidate.tgz "cnb-release-candidate/${LANGUAGE}_cnb-v$(cat version/version).tgz"
