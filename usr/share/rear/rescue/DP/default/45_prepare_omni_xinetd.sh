PROGS=( "${PROGS[@]}" xinetd )
COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/xinetd.conf /etc/xinetd.d/omni )
cat >$ROOTFS_DIR/etc/scripts/xinetd <<-EOF
# Data Protector needs omni service to be started from xinetd
echo "Starting a minimal xinetd daemon ..."
xinetd
EOF
chmod +x $ROOTFS_DIR/etc/scripts/xinetd
