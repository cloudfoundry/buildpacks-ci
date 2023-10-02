#!/usr/bin/env bash

set -eu
set -o pipefail
shopt -s inherit_errexit

function main {
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Script is not sourced. Please source this script."
    exit 1
  fi
  if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
    echo 'Please set the $AWS_ACCES_KEY_ID of the Principal before calling this script'
    exit 1
  fi
  if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    echo 'Please set the $AWS_SECRET_ACCES_KEY of the Principal before calling this script'
    exit 1
  fi
  if [ -z "${AWS_ASSUME_ROLE_ARN:-}" ]; then
    echo 'Please set the $AWS_ASSUME_ROLE_ARN of the role to be assumed before calling this script'
    exit 1
  fi

  uuid=$(cat /proc/sys/kernel/random/uuid)
  RESULT="$(aws sts assume-role --role-arn "${AWS_ASSUME_ROLE_ARN}" --role-session-name "buildpacks-ci-${uuid}")"

  export AWS_ACCESS_KEY_ID="$(echo "${RESULT}" |jq -r .Credentials.AccessKeyId)"
  export AWS_SECRET_ACCESS_KEY="$(echo "${RESULT}" |jq -r .Credentials.SecretAccessKey)"
  export AWS_SESSION_TOKEN="$(echo "${RESULT}" |jq -r .Credentials.SessionToken)"
}

function usage() {
  cat <<-USAGE
aws_assume_role.sh

Assumes the given role ARN by generating a set of temporary security credentials
Must be called with the Principal's creds provided via the following env vars set:
AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_ASSUME_ROLE_ARN.
You must already set up the AWS trust policy for the Principal to assume the role.
Script to be sourced.

USAGE
}

main "${@:-}"
