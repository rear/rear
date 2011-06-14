
# adjust some permissions
pushd $ROOTFS_DIR >&8
# SSH requires this
chmod $v 0700 root >&2
chmod $v 0755 var/lib/empty >&2
chown $v -R root.root root var/lib/empty >&2

popd >&8
