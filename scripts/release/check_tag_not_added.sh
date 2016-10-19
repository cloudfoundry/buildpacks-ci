#!/usr/bin/env bash
set -e

cd buildpack
git tag "v$(cat VERSION)"
