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

    # FIXME: I (jsmeix@suse.de) wonder if it is really right to proceed here
    # even if it could not find sysfs name for device - i.e. I wonder if it could be better
    # to skip the current multipath device and 'continue' with the next one in the loop
    # or to even error out here during "rear mkrescue" where the user can fix things, cf.
    # "Try hard to care about possible errors" at https://github.com/rear/rear/wiki/Coding-Style
    [[ -e /sys/block/$name ]]
    LogIfError "Did not find sysfs name for device $dm_name (/sys/block/$name)"

    dm_size=$(get_disk_size $name)
    # FIXME: I (jsmeix@suse.de) wonder if it is really right to proceed here even if it failed
    # to get size of the device. Perhaps dm_size is a required value in disklayout.conf?
    # I wonder if it is better to skip the current multipath device and 'continue' with the next one
    # or to even error out here during "rear mkrescue" where the user can fix things, cf.
    # "Try hard to care about possible errors" at https://github.com/rear/rear/wiki/Coding-Style
    test "$dm_size"
    LogIfError "Failed to get size of $name with get_disk_size"

    slaves=""
    for slave in /sys/block/$name/slaves/* ; do
        slaves+="$(get_device_name ${slave##*/}),"
    done

    dm_disktype=$(parted -s $dev_name print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " ")
    # FIXME: I (jsmeix@suse.de) wonder if it is really right to proceed here even if it failed
    # to determine dm_disktype. Perhaps dm_disktype is a required value in disklayout.conf?
    # I wonder if it is better to skip the current multipath device and 'continue' with the next one
    # or to even error out here during "rear mkrescue" where the user can fix things, cf.
    # "Try hard to care about possible errors" at https://github.com/rear/rear/wiki/Coding-Style

    echo "# Multipath /dev/mapper/$dm_name" >> $DISKLAYOUT_FILE
    echo "# Format: multipath <devname> <size(bytes)> <partition label type> <slaves>" >> $DISKLAYOUT_FILE
    echo "multipath /dev/mapper/$dm_name $dm_size $dm_disktype ${slaves%,}" >> $DISKLAYOUT_FILE

    extract_partitions "/dev/mapper/$dm_name" >> $DISKLAYOUT_FILE
done < <( dmsetup ls --target multipath )

if grep -q ^multipath $DISKLAYOUT_FILE ; then
    # See REQUIRED_PROGS below regarding what is actually required.
    # TODO: It seems this code here is a duplicate of what is done in prep/GNU/Linux/240_include_multipath_tools.sh
    # but (in contrast to here) the actual code in 240_include_multipath_tools.sh is only run if BOOT_OVER_SAN is true:
    PROGS+=( multipath kpartx multipathd mpathconf )
    COPY_AS_IS+=( /etc/multipath.conf /etc/multipath/* /lib*/multipath )

    # depending to the linux distro and arch, libaio can be located in different dir. (ex: /lib/powerpc64le-linux-gnu)
    for libdir in $(ldconfig -p | awk '/libaio.so/ { print $NF }' | xargs -n1 dirname | sort -u); do
        libaio2add+=" $libdir/libaio*"
    done
    LIBS+=( $libaio2add )
fi

# multipath is required in the recovery system if disklayout.conf contains at least one 'multipath' entry
# see layout/prepare/GNU/Linux/210_load_multipath.sh which programs will be run during "rear recover" in any case
# e.g. mpathconf is not called in any case and multipathd is only used when $list_mpath_device is true
# cf. https://github.com/rear/rear/issues/1963
grep -q '^multipath ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( multipath ) || true

