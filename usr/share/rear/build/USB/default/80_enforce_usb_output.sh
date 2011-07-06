# Make sure we use the correct OUTPUT in local.conf

real_output=$(source $ROOTFS_DIR/$CONFIG_DIR/local.conf; echo $OUTPUT)

if [[ "$real_output" == "USB" ]]; then
    return
fi

cat <<EOF >>$ROOTFS_DIR/$CONFIG_DIR/local.conf

# Added by udev workflow
OUTPUT=USB
EOF
