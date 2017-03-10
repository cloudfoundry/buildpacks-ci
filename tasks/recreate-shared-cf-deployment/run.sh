#!/bin/bash -l

set -o errexit
set -o nounset
set -o pipefail

gcp_windows_stemcell=$(ls gcp-windows-stemcell/light-bosh-stemcell*.tgz)
gcp_linux_stemcell="gcp-linux-stemcell/stemcell.tgz"

bosh2 -n upload-stemcell "$gcp_windows_stemcell"
bosh2 -n upload-stemcell "$gcp_linux_stemcell"

echo -e "\n\n======= Destroying old cf deployment ======="
bosh2 -n -d cf delete-deployment
echo -e "\n\n======= Destroyed ======="

echo -e "\n\n======= Creating new cf deployment ======="
echo "uaa_scim_users_admin_password: $CI_CF_SHARED_PASSWORD" > /tmp/deployment-vars.yml

bosh2 -n -d cf deploy cf-deployment/cf-deployment.yml \
--vars-store /tmp/deployment-vars.yml \
-v system_domain=$SYSTEM_DOMAIN \
-o cf-deployment/operations/windows-cell.yml \
-o buildpacks-ci/deployments/edge-shared/scale-down.yml
echo -e "\n\n======= Done! ======="
