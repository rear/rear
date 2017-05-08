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

    dm_size=$(get_disk_size $name)
    test "$dm_size"
    LogIfError "Failed to get size of $name with get_disk_size"

    slaves=""
    for slave in /sys/block/$name/slaves/* ; do
        slaves="$slaves$(get_device_name ${slave##*/}),"
    done

    echo "multipath /dev/mapper/$dm_name $dm_size ${slaves%,}" >> $DISKLAYOUT_FILE

    extract_partitions "/dev/mapper/$dm_name" >> $DISKLAYOUT_FILE
done < <( dmsetup ls --target multipath )

if grep -q ^multipath $DISKLAYOUT_FILE ; then
    PROGS=( "${PROGS[@]}" multipath kpartx multipathd )
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/multipath.conf /etc/multipath/* /lib*/multipath )

    # depending to the linux distro and arch, libaio can be located in different dir. (ex: /lib/powerpc64le-linux-gnu)
    for libdir in $(ldconfig -p | awk '/libaio.so/ { print $NF }' | xargs -n1 dirname | sort -u); do
        libaio2add="$libaio2add $libdir/libaio*"
    done
    LIBS=( "${LIBS[@]}" $libaio2add )
fi
