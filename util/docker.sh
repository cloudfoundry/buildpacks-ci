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
  mkdir -p /sys/fs/cgroup
  mountpoint -q /sys/fs/cgroup || \
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup

  mount -o remount,rw /sys/fs/cgroup

  # shellcheck disable=SC2162,SC2034
  sed -e 1d /proc/cgroups | while read sys hierarchy num enabled; do
    if [ "$enabled" != "1" ]; then
      # subsystem disabled; skip
      continue
    fi

    # shellcheck disable=SC2002
    grouping="$(cat /proc/self/cgroup | cut -d: -f2 | grep "\\<$sys\\>")"
    if [ -z "$grouping" ]; then
      # subsystem not mounted anywhere; mount it on its own
      grouping="$sys"
    fi

    mountpoint="/sys/fs/cgroup/$grouping"

    mkdir -p "$mountpoint"

    # clear out existing mount to make sure new one is read-write
    if mountpoint -q "$mountpoint"; then
      umount "$mountpoint"
    fi

    mount -n -t cgroup -o "$grouping" cgroup "$mountpoint"

    if [ "$grouping" != "$sys" ]; then
      if [ -L "/sys/fs/cgroup/$sys" ]; then
        rm "/sys/fs/cgroup/$sys"
      fi

      ln -s "$mountpoint" "/sys/fs/cgroup/$sys"
    fi
  done

  if ! test -e /sys/fs/cgroup/systemd; then
    mkdir -p /sys/fs/cgroup/systemd
    mount -t cgroup -o none,name=systemd cgroup /sys/fs/cgroup/systemd
  fi
}

function util::docker::devicecontrol::permit() {
  local devices_mount_info
  devices_mount_info="$(grep devices < /proc/self/cgroup)"

  if [ -z "$devices_mount_info" ]; then
    # cgroups not set up; must not be in a container
    return
  fi

  local devices_subsystems
  devices_subsystems="$(echo "$devices_mount_info" | cut -d: -f2)"

  local devices_subdir
  devices_subdir="$(echo "$devices_mount_info" | cut -d: -f3)"

  if [ "$devices_subdir" = "/" ]; then
    # we're in the root devices cgroup; must not be in a container
    return
  fi

  cgroup_dir=/tmp/devices-cgroup

  if [ ! -e ${cgroup_dir} ]; then
    # mount our container's devices subsystem somewhere
    mkdir ${cgroup_dir}
  fi

  if ! mountpoint -q ${cgroup_dir}; then
    if ! mount -t cgroup -o "$devices_subsystems" none ${cgroup_dir}; then
      return 1
    fi
  fi

  # permit our cgroup to do everything with all devices
  # ignore failure in case something has already done this; echo appears to
  # return EINVAL, possibly because devices this affects are already in use
  echo a > "${cgroup_dir}${devices_subdir}/devices.allow" || true
}

function util::docker::scratch::allocate() {
  util::print::info "[docker] * allocating scratch disk"

  mkdir -p "${SCRATCH_DIR}"

  if command -v mkfs.btrfs > /dev/null; then
    util::docker::devicecontrol::permit

    local loopdevice dockerroot
    rand="${RANDOM}"
    loopdevice="/dev/loop${rand}"
    dockerroot="/tmp/docker-root-${rand}"

    if [[ ! -e "${loopdevice}" ]]; then
      util::print::info "[docker]   * creating 20GB scratch file"

      dd if=/dev/zero of="${dockerroot}" bs=1024 count=20971520 > /dev/null 2>&1

      util::print::info "[docker]   * creating block device"
      mknod "${loopdevice}" b 7 "${rand}"
      losetup "${loopdevice}" "${dockerroot}"
    fi

    util::print::info "[docker]   * creating btrfs filesystem"
    mkfs.btrfs "${dockerroot}" > /dev/null

    util::print::info "[docker]   * mounting filesystem"
    mount "${dockerroot}" "${SCRATCH_DIR}"

    mkdir -p /etc/docker
    echo '{ "storage-driver": "btrfs" }' > /etc/docker/daemon.json
  fi
}

function util::docker::scratch::deallocate() {
  util::print::info "[docker] * deallocating scratch disk"

  util::print::info "[docker]   * unmounting filesystem"
  while [[ "$(grep "${SCRATCH_DIR}" < /proc/mounts)" != "" ]]; do
    if ! umount -A "${SCRATCH_DIR}" > /dev/null 2>&1; then
      sleep 1
    fi
  done

  util::print::info "[docker]   * removing block device"
  shopt -s nullglob
    local path
    for device in /dev/loop*; do
      path="$(echo "${device}" | grep "loop[[:digit:]]" || true)"
      if [[ "${path}" != "" && -e "${path}" ]]; then
        rm "${path}"
      fi
    done
  shopt -u nullglob

  util::print::info "[docker]   * deleting 20GB scratch file"
  find /tmp -type f -name 'docker-root-*' -delete
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
