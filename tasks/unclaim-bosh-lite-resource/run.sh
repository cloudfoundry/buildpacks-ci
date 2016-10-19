#!/usr/bin/env bash

set -ex

pushd resource-pools
  echo "Unclaiming $RESOURCE_NAME"
  git mv "$RESOURCE_TYPE/claimed/$RESOURCE_NAME" "$RESOURCE_TYPE/unclaimed/"
  git add "$RESOURCE_TYPE"
  git commit -m "Unclaim $RESOURCE_NAME via $PIPELINE_NAME pipeline"
popd

rsync -a resource-pools/ resource-pools-artifacts
