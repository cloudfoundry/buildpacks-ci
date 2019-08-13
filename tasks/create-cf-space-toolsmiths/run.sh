#!/bin/bash -l


set -o errexit
set -o pipefail
set -x

OUTPUT=cf-space

set +x
env_name="$(cat environment/name)"

ops_manager_username="pivotalcf"
ops_manager_password="$(jq -r .ops_manager.password environment/metadata )"
ops_manager_url="https://pcf.$env_name.cf-app.com"

TARGET="api.sys.$env_name.cf-app.com"
USERNAME="admin"
PASSWORD="$(om \
  --target "$ops_manager_url" \
  --username "$ops_manager_username" \
  --password "$ops_manager_password" \
  --skip-ssl-validation \
  credentials \
  --product-name cf \
  --credential-reference .uaa.admin_credentials \
  --format json | jq -r .password)"

cf api "$TARGET" --skip-ssl-validation || (sleep 4 && cf api "$TARGET" --skip-ssl-validation)
cf auth "$USERNAME" "$PASSWORD" || (sleep 4 && cf auth "$USERNAME" "$PASSWORD")
set -x

SPACE=$(openssl rand -base64 32 | base64 | head -c 8 | awk '{print tolower($0)}')
cf create-org "$ORG"
cf create-space "$SPACE" -o "$ORG" || (sleep 4 && cf create-space "$SPACE" -o "$ORG")

set +x

cat <<- EOM > "$OUTPUT/login"
  #!/usr/bin/env sh
  set +x
  echo "Logging in to $SPACE on $ORG on $TARGET"
  cf api "$TARGET" --skip-ssl-validation
  cf auth "$USERNAME" "$PASSWORD" 
  cf target -o "$ORG" -s "$SPACE"
EOM

set -x
chmod 755 "$OUTPUT/login"

echo "$SPACE" > "$OUTPUT/name"
echo "export SPACE=$SPACE" > "$OUTPUT/variables"
