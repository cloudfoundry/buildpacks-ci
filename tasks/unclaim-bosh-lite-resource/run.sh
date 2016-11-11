#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

set -x

pushd resource-pools
  echo "Unclaiming $RESOURCE_NAME"

  if [[ -f "$RESOURCE_TYPE/claimed/$RESOURCE_NAME" || -f "$RESOURCE_TYPE/unclaimed/$RESOURCE_NAME" ]]; then
    if [[ -f "$RESOURCE_TYPE/claimed/$RESOURCE_NAME" ]] ; then
      git mv "$RESOURCE_TYPE/claimed/$RESOURCE_NAME" "$RESOURCE_TYPE/unclaimed/"
      git add "$RESOURCE_TYPE"
      git commit -m "Unclaim $RESOURCE_NAME via $PIPELINE_NAME pipeline"
    elif [[ -f "$RESOURCE_TYPE/unclaimed/$RESOURCE_NAME" ]] ; then
      echo "$RESOURCE_NAME is already unclaimed"
    fi
  else
    echo "$RESOURCE_NAME does not currently exist in pool"
    git mv "$RESOURCE_TYPE/claimed/$RESOURCE_NAME" "$RESOURCE_TYPE/unclaimed/"
  fi
popd

rsync -a resource-pools/ resource-pools-artifacts
