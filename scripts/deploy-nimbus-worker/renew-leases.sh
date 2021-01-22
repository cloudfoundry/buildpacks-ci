#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function main {
  local username

# accept user's username as input (e.g. frankieg)
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --username|-u)
        username="${2}"
        shift 2
        ;;

      --help|-h)
        shift 1
        usage
        exit 0
        ;;

      "")
        # skip if the argument is empty
        shift 1
        ;;

      *)
        echo "unknown argument \"${1}\""
        exit 1
    esac
  done

  if [[ -z "${username:-}" ]]; then
    printf "\nthe --username flag is required\n"
    usage
    exit 1
  fi

  renew_lease ${username}
}

function usage() {
  cat <<-USAGE
renew_leases.sh --username <nimbus gateway username>

Renews the lease on all nimbus workers in the svc.buildpacks account

OPTIONS
  --help                                -h                            prints the command usage
  --username <nimbus gateway username>  -u <nimbus gateway username>  your VMware LDAP username
USAGE
}

function renew_lease(){
  username=${1}
  echo "Setting up nimbus login. Please save new key to ~/.ssh/id_rsa"

  ssh-keygen -t rsa
  ssh ${username}@nimbus-gateway mkdir -p .ssh
  cat ~/.ssh/id_rsa.pub | ssh ${username}@nimbus-gateway 'cat >> .ssh/authorized_keys && chmod 700 .ssh'

  echo "Logging into the nimbus-gateway"
  vm_json=$(ssh ${username}@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl --outputFormat=json list | grep json_info'")
  vms=$(echo ${vm_json} | jq -r '.json_info[] | keys[]')

  echo "Renewing leases.. this could take a couple min"
  for worker in ${vms}
    do
      echo Renewing "$worker" lease
      ssh ${username}@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl --lease=7 extend_lease ${worker}'"
    done

  echo "All leases renewed"
  echo "Cleaning up ssh-key from nimbus-gateway"
  ssh ${username}@nimbus-gateway bash -c "'rm -rf .ssh'"
}

main "${@:-}"
