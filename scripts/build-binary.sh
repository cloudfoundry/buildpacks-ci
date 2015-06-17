#!/bin/bash -l
set -e

cd binary-builder
./bin/binary-builder $BINARY_NAME $BINARY_VERSION
