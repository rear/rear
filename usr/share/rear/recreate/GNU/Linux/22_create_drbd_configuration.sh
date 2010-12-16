# Recreate the DRBD configuration if needed
# This covers the case of LVM on DRBD, where the DRBD is on physical partitions
# or on software raid.

# NOTE: "drbdadm -s /bin/drdbsetup" might be needed for some versions of DRBD

if [ -e /etc/drbd.conf ] ; then
    Log "Restoring DRBD configuration."

    modprobe drbd
    if [ $? -ne 0 ] ; then
        LogPrint "Failed to load DRBD module, please configure DRBD manually."
    fi
    
    mkdir -p /var/lib/drbd
    
    # LVM on DRBD
    # Recreate devices
    drbdadm create-md all
    
    # Only attach, do not start synchronization
    drbdadm attach all
    drbdadm -- --overwrite-data-of-peer primary all
    if [ $? -ne 0 ] ; then
        LogPrint "Failed to restore DRBD configuration, please configure DRBD manually."
    fi
    
    ## DRBD on LVM would look like:
    # drbdadm create-md all
    # drbdadm up all
fi
