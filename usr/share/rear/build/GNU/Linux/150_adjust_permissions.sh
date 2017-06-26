
# adjust some permissions
pushd $ROOTFS_DIR >/dev/null
# SSH requires this
chmod $v 0700 root >&2
chmod $v 0755 var/empty var/lib/empty >&2
chown $v -R root.root root var/empty var/lib/empty >&2

popd >/dev/null
