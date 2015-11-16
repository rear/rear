# Purpose: Make sure NBKDC agent gets started in the rescue system

# Copy init conf to start the agent service
# If no initconf exists, the agent is started by /etc/scripts/system-setup.d/90_start_nbkdc.sh
[[ -e /etc/init/rcmd-executor.conf ]] && cp $v /etc/init/rcmd-executor.conf $ROOTFS_DIR/etc/init/rcmd-executor.conf



