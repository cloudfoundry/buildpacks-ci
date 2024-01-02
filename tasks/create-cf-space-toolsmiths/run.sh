#!/bin/bash -l

set -o errexit
set -o pipefail
set -x

OUTPUT=cf-space

set +x

env_name="$(jq -r .name environment/metadata)"
ops_manager_username="$(jq -r .ops_manager.username environment/metadata)"
ops_manager_password="$(jq -r .ops_manager.password environment/metadata)"
ops_manager_url="$(jq -r .ops_manager.url environment/metadata)"

TARGET="$(jq -r .cf.api_url environment/metadata)"
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

retries=0
while ! cf create-space "$SPACE" -o "$ORG" && [ $retries -lt 4 ]; do
  echo "Failed to create space $SPACE in org $ORG, retrying..."
  retries=$((retries + 1))
  sleep 5
done

if [ $retries -eq 4 ]; then
  echo "Failed to create space $SPACE in org $ORG after $retries retries"
  exit 1
fi

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
