#!/usr/bin/env bash

set -exo pipefail

mv candidate/candidate.zip "release-candidate/nodejs_buildpack-v$(cat version/version).zip"