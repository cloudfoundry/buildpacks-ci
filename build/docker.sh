permit_device_control() {
  local devices_mount_info=$(cat /proc/self/cgroup | grep devices)

  if [ -z "$devices_mount_info" ]; then
    # cgroups not set up; must not be in a container
    return
  fi

  local devices_subsytems=$(echo $devices_mount_info | cut -d: -f2)
  local devices_subdir=$(echo $devices_mount_info | cut -d: -f3)

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
    mount -t cgroup -o $devices_subsytems none ${cgroup_dir}
  fi

  # permit our cgroup to do everything with all devices
  # ignore failure in case something has already done this; echo appears to
  # return EINVAL, possibly because devices this affects are already in use
  echo a > ${cgroup_dir}${devices_subdir}/devices.allow || true
}
export -f permit_device_control

make_and_setup() {
  [ -b /dev/loop$1 ] || mknod -m 0660 /dev/loop$1 b 7 $1
  losetup -f $2
}
export -f make_and_setup

start_docker() {
  mkdir -p /var/log
  mkdir -p /var/run

  # set up cgroups
  mkdir -p /sys/fs/cgroup
  mountpoint -q /sys/fs/cgroup || \
    mount -t tmpfs -o uid=0,gid=0,mode=0755 cgroup /sys/fs/cgroup

  for d in `sed -e '1d;s/\([^\t]\)\t.*$/\1/' /proc/cgroups`; do
    mkdir -p /sys/fs/cgroup/$d
    mountpoint -q /sys/fs/cgroup/$d || \
      mount -n -t cgroup -o $d cgroup /sys/fs/cgroup/$d
  done

  permit_device_control

  mkdir -p /var/lib/docker

  image=$(mktemp $PWD/docker.img.XXXXXXXX)
  dd if=/dev/zero of=${image} bs=1 count=0 seek=100G
  mkfs.ext4 -F ${image}

  i=0
  until make_and_setup $i $image; do
    i=$(expr $i + 1)
  done

  lo=$(losetup -a | grep ${image} | cut -d: -f1)

  mount ${lo} /var/lib/docker

  local server_args=""

  for registry in $1; do
    server_args="${server_args} --insecure-registry ${registry}"
  done

  docker daemon ${server_args} >/dev/null 2>&1 &
  trap stop_docker EXIT

  sleep 1

  until docker info >/dev/null 2>&1; do
    echo waiting for docker to come up...
    sleep 1
  done
}
export -f start_docker

stop_docker() {
  for pid in $(pidof docker); do
    kill -TERM $pid
  done

  umount /var/lib/docker/aufs || true
  umount /var/lib/docker || true
}
export -f stop_docker
