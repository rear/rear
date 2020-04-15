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

# drbdadm is required in the recovery system if disklayout.conf contains at least one 'drbd' entry
# see the create_drbd function in layout/prepare/GNU/Linux/150_include_drbd_code.sh
# what program calls are written to diskrestore.sh
# cf. https://github.com/rear/rear/issues/1963
grep -q '^drbd ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( drbdadm ) || true

