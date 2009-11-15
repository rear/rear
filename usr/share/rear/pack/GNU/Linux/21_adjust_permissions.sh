
# adjust some permissions
pushd $ROOTFS_DIR >/dev/null
# SSH requires this
chmod -v 0700 root 1>&2
popd >/dev/null
