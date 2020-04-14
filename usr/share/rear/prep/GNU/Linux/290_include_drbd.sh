# Include DRBD tools if it's running on the system

if lsmod | grep -q drbd ; then
    REQUIRED_PROGS+=( drbdadm drbdsetup drbdmeta )
    COPY_AS_IS+=( /etc/drbd.* )
    Log "Including DRBD tools."

    # note that filesystems on DRBD might have to be excluded from the backup
fi
