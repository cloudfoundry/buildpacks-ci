#!/bin/bash -l

pushd heroku-nanny
  bin/sanity-check-upstream
popd
