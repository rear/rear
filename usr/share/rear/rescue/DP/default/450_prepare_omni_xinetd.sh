# 450_prepare_omni_systemd.sh
# Make sure Data Protector INET gets included in the rescue image (if xinetd is used)

if [ -r "/etc/xinetd.d/omni" ]; then

PROGS+=( xinetd )
COPY_AS_IS+=( /etc/xinetd.conf /etc/xinetd.d/omni )
cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh <<-EOF
echo "Starting Data Protector daemon using xinetd ..."
xinetd
EOF
chmod $v +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh
Log "Created the Data Protector start-up script (90-omni.sh) for ReaR using xinetd"

fi
