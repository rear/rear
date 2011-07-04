# DRBD configuration

if [ -e /proc/drbd ] ; then
    Log "Saving DRBD configuration."

    for resource in $(drbdadm sh-resources) ; do
        dev=$(drbdadm sh-dev $resource)
        disk=$(drbdadm sh-ll-dev $resource)

        echo "drbd $dev $resource $disk" >> $DISKLAYOUT_FILE
    done
fi
