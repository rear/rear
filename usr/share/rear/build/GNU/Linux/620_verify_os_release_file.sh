# 620_verify_os_release_file.sh
# Because of issue 778 (where /etc/os-release is linked to /usr/lib/os-release) the copy of /etc/os-release fails
# This is the case on Fedora 23

[[ ! -f /etc/os-release ]] && return  # if /etc/os-release does not exist just return (pre-systemd distro)

[[ -h $ROOTFS_DIR/etc/os-release ]] && rm -f $ROOTFS_DIR/etc/os-release      # if it is a link remove it first

cp $v /etc/os-release  $ROOTFS_DIR/etc/os-release >&2
