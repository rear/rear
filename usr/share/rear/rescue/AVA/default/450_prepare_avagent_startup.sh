# 450_prepare_avagent_startup.sh
# make sure avagent gets started up in the rescue image

cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-avagent.sh <<-EOF
echo "Starting EMC Avamar daemon ..."
$AVA_ROOT_DIR/bin/avagent.bin --bindir="$AVA_ROOT_DIR/bin" --vardir="$AVA_ROOT_DIR/var" --sysdir="$AVA_ROOT_DIR/etc" --logfile="/tmp/avagent.log"
EOF

chmod +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-avagent.sh
Log "Created the EMC Avamar avagent start-up script (90-avagent.sh) for ReaR"
