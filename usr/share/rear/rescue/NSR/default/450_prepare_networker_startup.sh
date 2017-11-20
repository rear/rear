# 450_prepare_networker_startup.sh
# make sure nsrecexd gets started up in the rescue image

cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-networker.sh <<-EOF
echo "Starting EMC NetWorker nsrexecd daemon ..."
NSRRC=\$NSR_ROOT_DIR/nsrrc
NSR_ENVEXEC=/opt/nsr/admin/nsr_envexec

# networkerrc defines environment variables, such as LD_LIBRARY_PATH, required
# to run NetWorker daemons.
NETWORKERRC=/opt/nsr/admin/networkerrc

if [ -f /usr/sbin/nsrexecd ]; then
    "\$NSR_ENVEXEC" -u "\$NSRRC" -s "\$NETWORKERRC"  "/usr/sbin/nsrexecd"
else
    # In case /usr/sbin/nsrexecd does not exist ... 
    if [ -f /opt/networker/sbin/nsrexecd ]; then
    	(/opt/networker/sbin/nsrexecd) 2>&1
    fi
fi
EOF

chmod +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-networker.sh
Log "Created the EMC NetWorker nsrexecd start-up script (90-networker.sh) for ReaR"
