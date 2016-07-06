#!/bin/bash -l
set -e

cd buildpack
git tag v`cat VERSION`
