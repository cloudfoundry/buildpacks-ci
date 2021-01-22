#!/usr/bin/env bash

set -eu
set -o pipefail

readonly PROGDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

function main {
  local username deployment login_file

# accept user's username as input (e.g. frankieg)
  while [[ "${#}" != 0 ]]; do
    case "${1}" in
      --username|-u)
        username="${2}"
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

  if [[ -z "${deployment:-}" ]]; then
    printf "\nspecify 'public' or 'private' Concourse deployment\n"
    usage
    exit 1
  fi

  deploy_nimbus_worker ${username} ${deployment}
}

function usage() {
  cat <<-USAGE
deploy-nimbus-worker.sh --username <nimbus gateway username> <public | private>

Deploys a nimbus vsphere worker to the public concourse.

OPTIONS
  --help                                -h                            prints the command usage
  --username <nimbus gateway username>  -u <nimbus gateway username>  your VMware LDAP username
USAGE
}

function deploy_nimbus_worker(){
  local deployment login_file date_time ip_json ip temp_file vm_name

  username=${1}
  deployment=${2}

  date_time=$(date +%s)
  case "${deployment}" in
    "public")
      vm_name="buildpacks-concourse-worker-$date_time"
      ;;

    "private")
      vm_name="buildpacks-private-concourse-worker-$date_time"
      ;;

    *)
      echo "unknown deployment \"${deployment}\""
      exit 1
  esac


  login_file="$HOME/workspace/bp-envs/scripts/login_director_${deployment}"
  if [[ -f ${login_file} ]]; then
    source ${login_file}
  else
    printf "You must have the file: %s\n" ${login_file}
    exit 1
  fi

  echo "Setting up nimbus login. Please save new key to ~/.ssh/id_rsa"
  ssh-keygen -t rsa
  cat ~/.ssh/id_rsa.pub | ssh ${username}@nimbus-gateway 'mkdir -p .ssh && cat >> .ssh/authorized_keys && chmod 700 .ssh'

  printf "\nLogging in as: %s\n" ${username}
  printf "    Deploying a nimbus ovf template. This takes a few minutes...\n If the script hangs for more than a few minutes check the logs for the following:\n"
  printf "    'User svc.buildpacks cannot provision additional resources due to: X is using 100 percent CPU provisioned quota'\n"
  printf "    If this is the case, the deployment is 'scheduled' and will automatically resume when resources become available\n\n"

  ssh_command="USER=svc.buildpacks nimbus deploy ovf --lease=7.0 --queue --wait-scheduler ${vm_name}  NIMBUS_OVF_BASE/svc.buildpacks/buildpacks-concourse-worker/buildpacks-concourse-worker-ovf.ovf"
  ssh ${username}@nimbus-gateway bash -c "'$ssh_command'"

  # nimbus prefixes VM names with the user who creates them
  vm_name=svc.buildpacks-${vm_name}

  echo "Resolving worker IP Address..."
  ip_json=$(ssh ${username}@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl --outputFormat=json ip ${vm_name} | grep json_info'")
  ip=$(echo ${ip_json} | jq -r '.json_info[]."'${vm_name}'"')



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
