#!/bin/sh
set -e

cd nodejs-buildpack
../ci-tools/buildpack-builds --host=10.244.0.34.xip.io
