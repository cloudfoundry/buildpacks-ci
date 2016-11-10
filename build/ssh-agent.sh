#! /usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

if [[ -z "${SSH_AUTH_SOCK-}" ]]; then
  eval "$(ssh-agent)"
fi

