# Append /etc/drbdtab to the list of mountpoints, if it exists

if [ -e /etc/drbdtab ] ; then
    while read disk mp fs junk; do
        echo "$mp $disk $disk $fs" >> $VAR_DIR/recovery/mountpoint_device
    done < /etc/drbdtab
fi

