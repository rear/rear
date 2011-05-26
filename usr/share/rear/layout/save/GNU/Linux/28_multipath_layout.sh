# Describe multipath devices

while read dm_name junk ; do
    if [ ! -e /dev/mpath/$dm_name ] ; then
        Log "Did not find multipath device $dm_name in the expected location."
        continue
    fi

    # follow symlinks to find the real device
    dev_name=$(readlink -f /dev/mpath/$dm_name)
    # we try to find the sysfs name
    name=$(get_sysfs_name $dev_name)
    
    [[ -e /sys/block/$name ]]
    LogIfError "Did not find sysfs name for device $dm_name (/sys/block/$name)"
    
    slaves=""
    for slave in /sys/block/$name/slaves/* ; do
        slaves="$slaves$(get_device_name ${slave##*/}),"
    done
    
    echo "multipath /dev/mpath/$dm_name ${slaves%,}" >> $DISKLAYOUT_FILE
done < <( dmsetup ls --target multipath )
