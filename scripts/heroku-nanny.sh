#!/bin/bash -l

set -e

cd heroku-nanny
bin/sanity-check-upstream
