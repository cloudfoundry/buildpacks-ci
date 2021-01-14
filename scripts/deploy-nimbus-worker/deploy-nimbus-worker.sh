#!/usr/bin/env bash

set -eu
set -o pipefail

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

printf "\nLogging in as: %s\n" $username
printf "    Deploying a nimbus ovf template. This takes a few minutes...\n If the script hangs for more than a few minutes check the logs for the following:\n"
printf "    'User svc.buildpacks cannot provision additional resources due to: X is using 100 percent CPU provisioned quota'\n"
printf "    If this is the case, the deployment is 'scheduled' and will automatically resume when resources become available\n\n"
# deploy the buildpacks team OVF template with the svc.buildpacks service account
date_time=$(date +%s)
ssh_command="USER=svc.buildpacks nimbus deploy ovf --queue --wait-scheduler buildpacks-concourse-worker-$date_time  NIMBUS_OVF_BASE/svc.buildpacks/buildpacks-concourse-worker/buildpacks-concourse-worker-ovf.ovf"
ssh ${username}@nimbus-gateway bash -c "'$ssh_command'"

# get IP address from output
echo "Resolving worker IP Address..."
ip_json=$(ssh ${username}@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl --outputFormat=json ip svc.buildpacks-buildpacks-concourse-worker-$date_time | grep json_info'")
ip=$(echo ${ip_json} | jq -r '.json_info[]."svc.buildpacks-buildpacks-concourse-worker-'$date_time'"')


# ssh onto the machine and add the worker private key
echo "Accessing Concourse Credhub..."
source ~/workspace/bp-envs/scripts/login_director_public
# TODO Do something reasonable if that script isnt there

echo "Setting up credentials for worker..."
credhub get -n /bosh-buildpacks-public/concourse/nimbus_worker_private_key -q > /tmp/deleteme-private-key
scp /tmp/deleteme-private-key worker@${ip}:~/worker.pem
rm /tmp/deleteme-private-key

# get the ATC public key with ssh-keyscan
echo $(ssh-keyscan -p 2222 buildpacks.ci.cf-app.com 2> /dev/null) | sed -e "s/^\[buildpacks\.ci\.cf\-app\.com\]\:2222 //" > /tmp/deleteme-atc-public-key
scp /tmp/deleteme-atc-public-key worker@${ip}:~/host.pub
rm /tmp/deleteme-atc-public-key

# (maybe) modify the concourse.service file (e.g. to change the name)
echo "Modifying the Concourse configuration file"
cat concourse.service | sed -e "s/datetime/$date_time/" > /tmp/deleteme-concourse-config
scp /tmp/deleteme-concourse-config worker@${ip}:~/concourse.service.new
rm /tmp/deleteme-concourse-config

echo "Starting the worker up on Concourse"
# start the concourse process
# check that the worker has come online
ssh worker@${ip} bash -c "'sudo mv ~/concourse.service.new /etc/systemd/system/concourse.service && sudo systemctl daemon-reload && sudo systemctl restart concourse && sudo systemctl status concourse --no-pager --full'"

sleep 5
echo "Worker should be available:"
fly -t buildpacks workers | grep ${date_time}
}

function usage() {
  cat <<-USAGE
deploy-nimbus-worker.sh --username <nimbus gateway username>

Deploys a nimbus vsphere worker to the public concourse.

OPTIONS
  --help                                -h                            prints the command usage
  --username <nimbus gateway username>  -u <nimbus gateway username>  your VMware LDAP username
USAGE
}
main "${@:-}"
