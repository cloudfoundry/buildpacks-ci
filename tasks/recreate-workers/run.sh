#!/usr/bin/env bash

set -euo pipefail

source bp-envs/scripts/login_director_public

bosh -n -d concourse recreate --skip-drain worker
