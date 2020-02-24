#!/usr/bin/env bash

set -exo pipefail

mv candidate/*.zip "release-candidate/${LANGUAGE}-cnb-cf-v$(cat version/version).zip"
