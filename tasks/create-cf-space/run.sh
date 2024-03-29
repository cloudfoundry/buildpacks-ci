#!/bin/bash -l


set -o errexit
set -o pipefail
set -x

OUTPUT=cf-space

if [ -z "$TARGET" ]; then
  lock_name=$(cat "$ENV_POOL_RESOURCE/name")
  ENV_NAME="${lock_name//[[:digit:]]/}"
  TARGET="api.$ENV_NAME.$SYSTEM_DOMAIN"
fi

set +x
if [ -z "$PASSWORD" ]; then
  # TODO : remove this check after we've fully cut over to bbl 6
  if [ ! -f "$ENVS_DIR/$ENV_NAME/vars-store.yml" ]; then
    # shellcheck disable=SC2086
    eval "$(bbl --state-dir ${ENVS_DIR}/${ENV_NAME} print-env)"
    # shellcheck disable=SC2086
    PASSWORD=$(credhub get -n /bosh-${ENV_NAME}/cf/cf_admin_password -j | jq -r .value)
  else
    PASSWORD=$(grep "cf_admin_password:" "$ENVS_DIR/$ENV_NAME/vars-store.yml" | awk '{print $2}')
  fi
fi

cf api "$TARGET" --skip-ssl-validation || (sleep 4 && cf api "$TARGET" --skip-ssl-validation)
cf auth "$USERNAME" "$PASSWORD" "$CREDS_FLAG" || (sleep 4 && cf auth "$USERNAME" "$PASSWORD" "$CREDS_FLAG")
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

if [ -z "$CREDS_FLAG" ]; then
login=$(cat <<- EOM
  #!/usr/bin/env sh
  set +x
  echo "Logging in to $SPACE on $ORG on $TARGET"
  cf login -a "$TARGET" -u "$USERNAME" -p "$PASSWORD" --skip-ssl-validation -o "$ORG" -s "$SPACE"
EOM
)
else
login=$(cat <<- EOM
  #!/usr/bin/env sh
  set +x
  echo "Logging in to $SPACE on $ORG on $TARGET"
  cf api "$TARGET"
  cf auth "$USERNAME" "$PASSWORD" --client-credentials
  cf target -o "$ORG" -s "$SPACE"
EOM
)
fi


echo "${login}" > "$OUTPUT/login"

set -x
chmod 755 "$OUTPUT/login"

echo "$SPACE" > "$OUTPUT/name"
echo "export SPACE=$SPACE" > "$OUTPUT/variables"
