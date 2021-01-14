#!/usr/bin/env bash

# accept user's username as input (e.g. frankieg)
user_name="frankieg"

# TODO: Parse VM username and password from OVF metadata file
#
# deploy the buildpacks team OVF template with the svc.buildpacks service account
date_time=$(date +%s)
ssh_command="USER=svc.buildpacks nimbus deploy ovf --queue --wait-scheduler buildpacks-concourse-worker-$date_time  NIMBUS_OVF_BASE/svc.buildpacks/buildpacks-concourse-worker/buildpacks-concourse-worker-ovf.ovf"
ssh ${user_name}@nimbus-gateway bash -c "'$ssh_command'"

# get IP address from output
echo "Resolving worker IP"
ip_json=$(ssh ${user_name}@nimbus-gateway bash -c "'USER=svc.buildpacks nimbus-ctl --outputFormat=json ip svc.buildpacks-buildpacks-concourse-worker-$date_time | grep json_info'")
ip=$(echo ${ip_json} | jq -r '.json_info[]."svc.buildpacks-buildpacks-concourse-worker-'$date_time'"')


# ssh onto the machine and add the worker private key
echo "Accessing concourse credhub"
source ~/workspace/bp-envs/scripts/login_director_public
# TODO Do something reasonable if that script isnt there

echo "Setting up worker credentials"
credhub get -n /bosh-buildpacks-public/concourse/nimbus_worker_private_key -q > /tmp/deleteme-private-key
scp /tmp/deleteme-private-key worker@${ip}:~/worker.pem
rm /tmp/deleteme-private-key

# get the ATC public key with ssh-keyscan
echo $(ssh-keyscan -p 2222 buildpacks.ci.cf-app.com 2> /dev/null) | sed -e "s/^\[buildpacks\.ci\.cf\-app\.com\]\:2222 //" > /tmp/deleteme-atc-public-key
scp /tmp/deleteme-atc-public-key worker@${ip}:~/host.pub
rm /tmp/deleteme-atc-public-key

# (maybe) modify the concourse.service file (e.g. to change the name)
echo "Modifying concourse config"
cat concourse.service | sed -e "s/datetime/$date_time/" > /tmp/deleteme-concourse-config
scp /tmp/deleteme-concourse-config worker@${ip}:~/concourse.service.new
rm /tmp/deleteme-concourse-config

# start the concourse process
# check that the worker has come online
ssh worker@${ip} bash -c "'sudo mv ~/concourse.service.new /etc/systemd/system/concourse.service && sudo systemctl daemon-reload && sudo systemctl restart concourse && sudo systemctl status concourse --no-pager --full'"

