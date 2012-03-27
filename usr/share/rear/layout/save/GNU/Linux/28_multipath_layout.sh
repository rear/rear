# Describe multipath devices

while read dm_name junk ; do
    if [ ! -e /dev/mapper/$dm_name ] ; then
        Log "Did not find multipath device $dm_name in the expected location."
        continue
    fi

    # follow symlinks to find the real device
    dev_name=$(readlink -f /dev/mapper/$dm_name)
    # we try to find the sysfs name
    name=$(get_sysfs_name $dev_name)

    [[ -e /sys/block/$name ]]
    LogIfError "Did not find sysfs name for device $dm_name (/sys/block/$name)"

    slaves=""
    for slave in /sys/block/$name/slaves/* ; do
        slaves="$slaves$(get_device_name ${slave##*/}),"
    done

    echo "multipath /dev/mapper/$dm_name ${slaves%,}" >> $DISKLAYOUT_FILE

    extract_partitions "/dev/mapper/$dm_name" >> $DISKLAYOUT_FILE
done < <( dmsetup ls --target multipath )

if grep -q ^multipath $DISKLAYOUT_FILE ; then
    PROGS=( "${PROGS[@]}" multipath kpartx multipathd )
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/multipath.conf /lib*/multipath )
    LIB=( "${PROGS[@]}" libaio* )
fi
