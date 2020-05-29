#!/usr/bin/env bash

set -euo pipefail

if [[ "${CI_INSTANCE}" == "public" ]]; then
  login_script=bp-envs/scripts/login_director_public
  ci_url=https://buildpacks.ci.cf-app.com
elif [[ "${CI_INSTANCE}" == "private" ]]; then
  login_script=bp-envs/scripts/login_director_private
  ci_url=https://buildpacks-private.ci.cf-app.com
else
  echo "CI_INSTANCE must be 'public' or 'private'"
  exit 1
fi

source "${login_script}"

bosh -n -d concourse recreate --skip-drain worker

fly -t buildpacks login -c "${ci_url}" -u "${CI_USERNAME}" -p "${CI_PASSWORD}"
fly -t buildpacks prune-worker --all-stalled
