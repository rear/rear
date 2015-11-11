# Purpose: Make sure NBKDC agent gets started in the rescue system

source $VAR_DIR/recovery/nbkdc_settings
# created by rear/lib/nbkdc-functions.sh

cat >$ROOTFS_DIR/etc/scripts/system-setup.d/99-start-nbkdc.sh <<-EOF
#echo "Starting NovaBACKUP DataCenter Agent service ..."
# start included NBK DC client so file restore can happen:

# Check if working directories of NBK DC datamover exist
if [ ! -d $NBKDC_HIB_LST ]; then
    mkdir $NBKDC_HIB_LST
fi
if [ ! -d $NBKDC_HIB_TMP ]; then
    mkdir $NBKDC_HIB_TMP
fi
if [ ! -d $NBKDC_HIB_TPD ]; then
    mkdir $NBKDC_HIB_TPD
fi
if [ ! -d $NBKDC_HIB_TAP ]; then
    mkdir $NBKDC_HIB_TAP
fi
if [ ! -d $NBKDC_HIB_MSG ]; then
    mkdir $NBKDC_HIB_MSG
fi
if [ ! -d $NBKDC_HIB_LOG ]; then
    mkdir $NBKDC_HIB_LOG
fi

# Run a checkscript for the datamover to set required soft links and acls
chmod +x $NBKDC_HIB_DIR/finHib
cd $NBKDC_HIB_DIR && ./finHib

# Do some cleanup for the rcmd-executor
rm -f $NBKDC_DIR/rcmd-executor/tmp/*
rm -f /var/run/rcmd-executor.pid

# Create the NBK DC Agent service
$NBKDC_DIR/rcmd-executor/rcmd-executor create > $NBKDC_DIR/log/rcmd-executor.service.log
# Now start the NBK DC Agent to accept restores
$NBKDC_DIR/rcmd-executor/rcmd-executor start >> $NBKDC_DIR/log/rcmd-executor.service.log

# Wait and check if we are running
sleep 2
if [ -e /var/run/rcmd-executor.pid ]; then
    echo "NovaBACKUP DataCenter Agent started ..."
else
    echo "NovaBACKUP DateCenter Agent FAILED to start ..."
    echo "Please check check the logfile"
    echo "$NBKDC_DIR/log/rcmd-executor.log"
    echo "and start the agent found in"
    echo "$NBKDC_DIR/rcmd-executor/"
fi

EOF

chmod +x $ROOTFS_DIR/etc/scripts/system-setup.d/99-start-nbkdc.sh
Log "Created the NovaBACKUP DataCenter Agent start-up script (99-start-nbkdc.sh)"

