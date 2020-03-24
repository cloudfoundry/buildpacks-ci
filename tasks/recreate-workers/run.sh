#!/usr/bin/env bash

set -euo pipefail

source bp-envs/scripts/login_director_public

bosh -n -d concourse recreate --skip-drain worker

fly -t buildpacks login -c https://buildpacks.ci.cf-app.com -u "${CI_USERNAME}" -p "${CI_PASSWORD}"
fly -t buildpacks prune-worker --all-stalled
