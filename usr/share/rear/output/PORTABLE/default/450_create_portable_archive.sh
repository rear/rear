local archive_file="$TMP_DIR/$OUTPUT_PREFIX-portable.tar.gz"

tar $v -czf "$archive_file" -C $ROOTFS_DIR --exclude="$VAR_DIR/output/*" usr/sbin/rear etc/rear usr/share/rear var/lib/rear "$SHARE_DIR" "$VAR_DIR" || Error "Failed to create portable archive '$archive_file'"

RESULT_FILES+=( "$archive_file" )
