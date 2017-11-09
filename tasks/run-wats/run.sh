#!/bin/bash
set -xeu

build_dir=${PWD}

export CONFIG
original_config="$PWD/integration-config/${CONFIG_FILE_PATH}"

if ${CAPTURE_LOGS}; then
  CONFIG=$(mktemp)
  jq ".artifacts_directory=\"${build_dir}/wats-trace-output\"" "${original_config}" > "${CONFIG}"
else
  CONFIG=${original_config}
fi

cd wats

export CF_DIAL_TIMEOUT=11

export CF_PLUGIN_HOME=$HOME

./scripts/run_wats.sh ../integration-config/"${CONFIG_FILE_PATH}" \
-keepGoing \
-randomizeAllSpecs \
-slowSpecThreshold=120 \
-focus="CredHub" \
-nodes="${NODES}" \
-skip="${SKIP_REGEXP}"

