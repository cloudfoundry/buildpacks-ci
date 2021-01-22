#!/usr/bin/env bash

set -eu
set -o pipefail

echo "Setting up nimbus login. Please save new key to ~/.ssh/id_rsa"

ssh-keygen -t rsa
ssh swigmore@nimbus-gateway mkdir -p .ssh
cat ~/.ssh/id_rsa.pub | ssh swigmore@nimbus-gateway 'cat >> .ssh/authorized_keys && chmod 700 .ssh'

# echo "Logging into the nimbus-gateway"
# vm_json=$(ssh swigmore@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl --outputFormat=json list | grep json_info'")
# vms=$(echo ${vm_json} | jq -r '.json_info[] | keys[]')

# echo "Renewing leases.. this could take a couple min"
# for worker in ${vms}
#   do
#     echo Renewing "$worker" lease
#     # ssh swigmore@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl --lease=7 extend_lease ${worker}'"
#     ssh swigmore@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl ip ${worker}'"
#   done

echo "All leases renewed"
echo "Cleaning up ssh-key from nimbus-gateway"
ssh swigmore@nimbus-gateway bash -c "'rm -rf .ssh'"
