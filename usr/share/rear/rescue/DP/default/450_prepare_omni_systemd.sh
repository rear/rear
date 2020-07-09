# 450_prepare_omni_systemd.sh
# Make sure Data Protector INET gets included in the rescue image (if systemd is used)

# Nothing to do when systemd is not used
test -r "/usr/lib/systemd/system/omni.socket" || return 0

PROGS+=( systemd )
COPY_AS_IS+=( /usr/lib/systemd/system/omni.socket /usr/lib/systemd/system/omni@.service /etc/systemd/system/sockets.target.wants/omni.socket )

cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-omni.sh <<-EOF
echo "Starting Data Protector daemon using systemd..."
systemctl start omni.socket
EOF

chmod +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-omni.sh
Log "Created the Data Protector start-up script (90-omni.sh) for ReaR using systemd"
