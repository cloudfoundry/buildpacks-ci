#!/bin/bash

set -eu
set -o pipefail

TASKDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TASKDIR
TMPDIR=$(mktemp -d)

readonly LOCK_DIR="${PWD}/lock"

#shellcheck source=../../../util/print.sh
source "${PWD}/ci/util/print.sh"

function main() {
  util::print::title "[task] executing"

  cfd::checkout
  director::login
  stemcell::windows::upload
  releases::windows::upload
  cf::deploy
}

function cfd::checkout() {
  local version
  version="$(jq -r '.["cf-deployment_version"]' < "${PWD}/lock/metadata")"
  echo "Toolsmith env is on cf-deployment version ${version}"

	pushd "${PWD}/cf-deployment" > /dev/null
		echo "Checking out cf-deployment version ${version}"
		# Check if version contains the "v" prefix
		if [[ "${version}" =~ ^v ]]; then
      git checkout "${version}"
    else
      git checkout "v${version}"
    fi
	popd > /dev/null
}

function director::login() {
	util::print::info "[task] * logging into bosh director"

	eval "$(bbl print-env --metadata-file "${PWD}/lock/metadata")"
}

function stemcell::windows::upload() {
  if [[ -z "${DEPLOY_WINDOWS_CELL}" ]]; then
    return
  fi

	util::print::info "[task] * uploading windows stemcell"
	bosh upload-stemcell https://bosh.io/d/stemcells/bosh-google-kvm-windows2019-go_agent
}

function releases::windows::upload() {
  if [[ -z "${DEPLOY_WINDOWS_CELL}" ]]; then
    return
  fi

	util::print::info "[task] * uploading compiled releases for windows vms"

	grep url "${PWD}/cf-deployment/operations/experimental/use-compiled-releases-windows.yml" \
    | xargs -I{} echo {} \
    | cut -d" " -f2 \
    | xargs -I{} bosh upload-release {}
}

function cf::deploy() {
	util::print::info "[task] * deploying"

	local name
	name="$(jq -r .name "${LOCK_DIR}/metadata")"

	pushd "${PWD}/cf-deployment" > /dev/null
    local operations arguments
    operations=(
      "${PWD}/operations/experimental/fast-deploy-with-downtime-and-danger.yml" \
      "${PWD}/operations/use-compiled-releases.yml" \
      "${PWD}/operations/scale-to-one-az.yml" \
      "${PWD}/operations/disable-dynamic-asgs.yml" \
    )

    if [[ -n "${ADD_CFLINUXFS3_STACK}" ]]; then
      bosh upload-release https://bosh.io/d/github.com/cloudfoundry/cflinuxfs3-release
      util::print::info "[task] * uploaded cflinuxfs3 release from bosh.io"

      operations+=(
        "${TASKDIR}/operations/add-cflinuxfs3-to-current.yml" \
        "${TASKDIR}/operations/cflinuxfs3-rootfs-certs.yml" \
      )
      util::print::info "[task] * added cflinuxfs3 opsfiles to deploy command"
    fi

    if [[ -n "${DEPLOY_WINDOWS_CELL}" ]]; then
      operations+=(
        "${PWD}/operations/windows2019-cell.yml" \
        "${PWD}/operations/use-latest-windows2019-stemcell.yml" \
        "${PWD}/operations/use-online-windows2019fs.yml" \
        "${PWD}/operations/experimental/use-compiled-releases-windows.yml"
      )
    fi

    if [[ -n "${SCALE_DIEGO_CELLS}" ]]; then
      operations+=(
        "${TASKDIR}/operations/scale-api-and-diego-cells.yml"
      )
    fi

    arguments=()
    for operation in "${operations[@]}"; do
      arguments+=(-o "${operation}")
    done

    sys_domain="$(jq -r .cf.api_url "${LOCK_DIR}/metadata" | sed 's|api\.||')"

    util::print::info "[task] * starting deploy command"
		bosh -n -d cf deploy "${PWD}/cf-deployment.yml" \
			-v system_domain="${sys_domain}" \
      "${arguments[@]}"
    util::print::info "[task] * deploy successful"
	popd > /dev/null
}

main "${@}"
