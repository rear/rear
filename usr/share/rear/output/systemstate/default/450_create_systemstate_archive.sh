local archive_file="$SYSTEMSTATE_DIR/$SYSTEMSTATE_PREFIX.tar.gz"

for conf in local site; do
    cp "$CONFIG_DIR/${conf}.conf" "$ROOTFS_DIR/etc/rear/${conf}.conf"
done

for dir in layout recovery sysreqs; do
    mkdir -p "$ROOTFS_DIR/var/lib/rear/$dir"
    cp -R "$VAR_DIR/$dir/." "$ROOTFS_DIR/var/lib/rear/$dir"
done

mkdir -p "$SYSTEMSTATE_DIR"
tar $v -czf "$archive_file" -C $ROOTFS_DIR etc/rear var/lib || Error "Failed to create archive '$archive_file'"
