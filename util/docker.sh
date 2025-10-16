#!/bin/bash

set -eu
set -o pipefail

# shellcheck source=./print.sh
source "$(dirname "${BASH_SOURCE[0]}")/print.sh"

readonly LOG_FILE="${LOG_FILE:-/tmp/docker.log}"
readonly SKIP_PRIVILEGED="${SKIP_PRIVILEGED:-false}"
readonly PID_FILE=/tmp/docker.pid
readonly SCRATCH_DIR=/scratch/docker

function util::docker::start() {
  util::print::title "[docker] boot sequence"

  if docker info >/dev/null 2>&1; then
    util::print::warn "[docker] daemon already running"
    return
  fi

  util::docker::privileges::elevate
  util::docker::scratch::allocate
  util::docker::daemon::start
}

function util::docker::stop() {
  util::print::title "[docker] shutdown sequence"

  util::docker::daemon::stop
  util::docker::scratch::deallocate
}

function util::docker::privileges::elevate() {
  if [[ "${SKIP_PRIVILEGED}" != "false" ]]; then
    return
  fi

  util::print::info "[docker] * elevating privileges"
  util::docker::cgroups::sanitize

  # check for /proc/sys being mounted readonly, as systemd does
  if grep '/proc/sys\s\+\w\+\s\+ro,' /proc/mounts >/dev/null; then
    mount -o remount,rw /proc/sys
  fi
}

function util::docker::cgroups::sanitize() {
  if [ -e /sys/fs/cgroup/cgroup.controllers ]; then
    util::print::info "[docker]   * cgroup v2 detected"
    return 0
  fi

  util::print::error "[docker]   * cgroup v1 detected but no longer supported"
  util::print::error "[docker]   * This infrastructure requires cgroup v2 (Ubuntu 22.04+/Kubernetes 1.25+)"
  exit 1
}

function util::docker::scratch::allocate() {
  util::print::info "[docker] * allocating scratch disk"

  mkdir -p "${SCRATCH_DIR}"
}

function util::docker::scratch::deallocate() {
  util::print::info "[docker] * deallocating scratch disk"
}

function util::docker::daemon::start() {
  util::print::printf "[docker] * starting daemon "

  local mtu
  mtu="$(cat "/sys/class/net/$(ip route get 8.8.8.8 | awk '{ print $5 }')/mtu")"

  dockerd \
    --data-root "${SCRATCH_DIR}" \
    --mtu "${mtu}" \
    > "$LOG_FILE" \
    2>&1 \
    &
  echo "${!}" > "${PID_FILE}"

  until docker info >/dev/null 2>&1; do
    util::print::printf "*"
    sleep 1
  done

  util::print::info " done"
}

function util::docker::daemon::stop() {
  if [[ -e "${PID_FILE}" ]]; then
    util::print::info "[docker] * stopping daemon"

    kill "$(cat "${PID_FILE}")"
  fi
}
