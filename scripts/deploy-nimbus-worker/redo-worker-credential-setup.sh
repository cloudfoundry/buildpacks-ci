#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function main {
  local username worker deploymeny login_file

# accept user's username as input (e.g. frankieg)
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --username|-u)
        username="${2}"
        shift 2
        ;;

      --worker|-w)
        worker="${2}"
        shift 2
        ;;

      "public")
        deployment="${1}"
        shift 1
        ;;

      "private")
        deployment="${1}"
        shift 1
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

  if [[ -z "${worker:-}" ]]; then
    printf "\nthe --worker flag is required\n"
    usage
    exit 1
  fi

  if [[ -z "${deployment:-}" ]]; then
    printf "\nspecify 'public' or 'private' Concourse deployment\n"
    usage
    exit 1
  fi

  redo-worker-credential-setup ${username} ${worker} ${deployment}
}

function usage() {
  cat <<-USAGE
redo-worker-credential-setup.sh --username <nimbus gateway username> --worker <name of nimbus worker> <public | private>

If you're having problems with connecting a Nimbus worker to Concourse, run this script to redo the Concourse credential set up.

OPTIONS
  --help                                -h                            prints the command usage
  --username <nimbus gateway username>  -u <nimbus gateway username>  your VMware LDAP username
  --worker  <nimbus worker name>        -w <nimbus worker name>       the name of the Nimbus worker (e.g. svc.buildpacks-buildpacks-concourse-worker-XXXXXXX)
USAGE
}

function redo-worker-credential-setup(){
  local login_file date_time ip_json ip temp_file vm_name

  username=${1}
  worker=${2}
  deployment=${3}

  date_time=$(sed "s/-/ /g" <<< "$worker" | awk '{print $NF}')

  # nimbus prefixes VM names with the user who creates them
  vm_name=${worker}

  echo "Resolving worker IP Address..."
  echo $vm_name
  ip_json=$(ssh ${username}@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl --outputFormat=json ip ${vm_name} | grep json_info'")
  ip=$(echo ${ip_json} | jq -r '.json_info[]."'${vm_name}'"')

  login_file="$HOME/workspace/bp-envs/scripts/login_director_${deployment}"
  if [[ -f ${login_file} ]]; then
    source ${login_file}
  else
    printf "You must have the file: %s\n" ${login_file}
    exit 1
  fi
  echo "Accessing Concourse Credhub..."
  source ${login_file}

  echo "Setting up worker login with ssh-keys"
  cat ~/.ssh/id_rsa.pub | ssh worker@${ip} 'mkdir -p .ssh && cat >> .ssh/authorized_keys && chmod 700 .ssh'

  temp_file="/tmp/deleteme-nimbus-deploy"
  credhub get -n /bosh-buildpacks-${deployment}/concourse/nimbus_worker_private_key -q > ${temp_file}
  scp ${temp_file} worker@${ip}:~/worker.pem
  rm ${temp_file}

  # # get the ATC public key with ssh-keyscan
  case "${deployment}" in
    "public")
      echo $(ssh-keyscan -p 2222 buildpacks.ci.cf-app.com 2> /dev/null) | sed -e "s/^\[buildpacks\.ci\.cf\-app\.com\]\:2222 //" > ${temp_file}
      ;;

    "private")
      echo $(ssh-keyscan -p 2222 buildpacks-private.ci.cf-app.com 2> /dev/null) | sed -e "s/^\[buildpacks\-private\.ci\.cf\-app\.com\]\:2222 //" > ${temp_file}
      ;;

    *)
      echo "unknown deployment \"${deployment}\""
      exit 1
  esac

  scp ${temp_file} worker@${ip}:~/host.pub
  rm ${temp_file}

  echo "Modifying the Concourse configuration file"
  cat ${PROGDIR}/concourse.service.${deployment} | sed -e "s/datetime/$date_time/" > ${temp_file}
  scp ${temp_file} worker@${ip}:~/concourse.service.new
  rm ${temp_file}

  echo "Starting the concourse process on the worker"
  # start the concourse process
  # check that the worker has come online
  ssh worker@${ip} bash -c "'sudo mv ~/concourse.service.new /etc/systemd/system/concourse.service && sudo systemctl daemon-reload && sudo systemctl restart concourse && sudo systemctl status concourse --no-pager --full'"

  echo "Worker should be available, run 'fly -t <buildpacks|buildpacks-private> workers' to check"

  echo "Cleaning up ssh-key from nimbus-gateway and worker"
  ssh ${username}@nimbus-gateway bash -c "'rm -rf .ssh'"
  ssh worker@${ip} bash -c "'rm -rf .ssh'"
}

main "${@:-}"
