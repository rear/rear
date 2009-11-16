
# adjust some permissions
pushd $ROOTFS_DIR >/dev/null
# SSH requires this
chmod -v 0700 root 1>&2
chmod -v 0755 var/lib/empty 1>&2
chown -vR root.root root var/lib/empty 1>&2

popd >/dev/null
