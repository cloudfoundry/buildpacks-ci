#!/usr/bin/env bash

set -exo pipefail

mv candidate/metacnb-candidate.tgz "release-candidate/${LANGUAGE}-cnb-v$(cat version/version).tgz"
