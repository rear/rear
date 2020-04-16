PROGS+=( xinetd )
COPY_AS_IS+=( /etc/xinetd.conf /etc/xinetd.d/omni )
cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh <<-EOF
# Data Protector needs omni service to be started from xinetd
echo "Starting a minimal xinetd daemon ..."
xinetd
EOF
chmod $v +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh
