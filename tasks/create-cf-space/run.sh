#!/bin/bash -l

set -o errexit
set -o pipefail
set -x

OUTPUT=cf-space

if [ -n "$TARGET" ]; then
  ENV_NAME=$(cat "$ENV_POOL_RESOURCE/name")
  TARGET="api.$ENV_NAME.$SYSTEM_DOMAIN"
fi

set +x
if [ -n "$PASSWORD" ]; then
  PASSWORD=$(grep "cf_admin_password:" "$ENVS_DIR/$ENV_NAME/vars-store.yml" | awk '{print $2}')
fi

set -o nounset

cf api "$TARGET" --skip-ssl-validation || (sleep 4 && cf api "$TARGET" --skip-ssl-validation)
cf auth "$USERNAME" "$PASSWORD" || (sleep 4 && cf auth "$USERNAME" "$PASSWORD")
set -x

SPACE=$(openssl rand -base64 32 | base64 | head -c 8 | awk '{print tolower($0)}')
cf create-org "$ORG"
cf create-space "$SPACE" -o "$ORG" || (sleep 4 && cf create-space "$SPACE" -o "$ORG")

set +x
cat > "$OUTPUT/login" << EOF
#!/usr/bin/env sh
set +x
echo "Logging in to $SPACE on $ORG on $TARGET"
cf login -a "$TARGET" -u "$USERNAME" -p "$PASSWORD" --skip-ssl-validation -o "$ORG" -s "$SPACE"
EOF
set -x
chmod 755 "$OUTPUT/login"

echo "$SPACE" > "$OUTPUT/name"
echo "export SPACE=$SPACE" > "$OUTPUT/variables"
