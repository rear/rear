# DRBD configuration

if [ -e /proc/drbd ] ; then
    Log "Saving DRBD configuration."

    for resource in $(drbdadm sh-resources) ; do
        dev=( $(drbdadm sh-dev $resource) )
        disk=( $(drbdadm sh-ll-dev $resource) )

        for i in ${!dev[*]}; do
            vol_dev=${dev[$i]}
            vol_disk=$(get_device_name ${disk[$i]})
            echo "drbd $vol_dev $resource $vol_disk" >> $DISKLAYOUT_FILE
        done
    done
fi
