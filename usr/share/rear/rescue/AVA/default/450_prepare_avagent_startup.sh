# 450_prepare_avagent_startup.sh
# make sure avagent startup scripts gets included in the rescue image

mkdir -p $ROOTFS_DIR/etc/systemd/system
cp /run/systemd/generator.late/avagent.service $ROOTFS_DIR/etc/systemd/system/avagent.service

cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-avagent.sh <<-EOF
echo "Starting EMC Avamar daemon ..."
systemctl start avagent
EOF

chmod +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-avagent.sh
Log "Created the EMC Avamar avagent start-up script (90-avagent.sh) for ReaR"
