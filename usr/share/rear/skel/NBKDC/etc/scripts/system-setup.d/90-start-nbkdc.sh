
source $VAR_DIR/recovery/nbkdc_settings

# Check if working directories of NBK DC datamover exist and prepare the DataMover

for d in $NBKDC_HIB_LST $NBKDC_HIB_TMP $NBKDC_HIB_TPD $NBKDC_HIB_TAP $NBKDC_HIB_MSG $NBKDC_HIB_LOG; do
    [[ -d "$d" ]] || mkdir $v -p "$d"
done

# Run a checkscript for the datamover to set required soft links and acls
chmod +x $NBKDC_HIB_DIR/finHib
cd $NBKDC_HIB_DIR && ./finHib

# Now create and start the NBKDC agent service if it is not already running
if [ ! -e /var/run/rcmd-executor.pid ]; then
    # Create the NBK DC Agent service
    $NBKDC_DIR/rcmd-executor/rcmd-executor create > $NBKDC_DIR/log/rcmd-executor.service.log
    # Now start the NBK DC Agent to accept restores
    $NBKDC_DIR/rcmd-executor/rcmd-executor start >> $NBKDC_DIR/log/rcmd-executor.service.log
fi
