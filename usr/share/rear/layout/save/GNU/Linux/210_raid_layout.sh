# Save the Software RAID layout

# Nothing to do when there is no /proc/mdstat
test -e /proc/mdstat || return 0

# Nothing to do when /proc/mdstat does not contain "blocks"
grep -q blocks /proc/mdstat || return 0

Log "Saving Software RAID configuration"

# Subshell that appends to disklayout.conf
(
    # Have 'mdadm --detail --scan --config=partitions' output as comment in disklayout.conf:
    ( echo "Software RAID devices (mdadm --detail --scan --config=partitions)" ; mdadm --detail --scan --config=partitions ) | grep -v '^$' | sed -e 's/^/# /'

    local array raiddevice junk
    local basename
    local line
    locat metadata level raid_devices uuid name spare_devices layout chunksize component_devices size
    local container array_size
    local param copies number
    local component_device

    # Read 'mdadm --detail --scan --config=partitions' output which looks like
    # ARRAY /dev/md/raid1sdab metadata=1.0 name=any:raid1sdab UUID=8d05eb84:2de831d1:dfed54b2:ad592118
    # for a RAID1 array and for a RAID CONTAINER with IMSM metadata it looks like
    # ARRAY /dev/md/imsm0 metadata=imsm UUID=4d5cf215:80024c95:e19fdff4:2fba35a8
    # ARRAY /dev/md/Volume0_0 container=/dev/md/imsm0 member=0 UUID=ffb80762:127807b3:3d7e4f4d:4532022f
    # cf. https://github.com/rear/rear/pull/2702#issuecomment-968904230
    while read array raiddevice junk ; do

        # Skip if it is not an "ARRAY":
        test "$array" = "ARRAY" || continue

        # Do not use an array name from a previous run of the while loop:
        name=""
        basename=${raiddevice##*/}
        # When raiddevice is a symlink like /dev/md/raid1sdab -> /dev/md127
        # Use the kernel device node and set the array name to the symlink's basename:
        if test -h $raiddevice ; then
            raiddevice=$( readlink -e $raiddevice )
            name=$basename
        fi

        # We use the detailed mdadm output quite a lot so run the mdadm command only once:
        mdadm_details="$TMP_DIR/mdraid.$basename"
        mdadm --misc --detail $raiddevice | grep -v '^$' > $mdadm_details

        # Have 'mdadm --misc --detail $raiddevice' output as comment in disklayout.conf:
        ( echo "Software RAID $name device $raiddevice (mdadm --misc --detail $raiddevice)" ; cat $mdadm_details ) | sed -e 's/^/# /'

        # Extract values:
        # Example 'mdadm --misc --detail $raiddevice' output for a RAID1 array:
        #
        # /dev/md/raid1sdab:
        #            Version : 1.0
        #      Creation Time : Wed Oct 13 13:17:13 2021
        #         Raid Level : raid1
        #         Array Size : 12582784 (12.00 GiB 12.88 GB)
        #      Used Dev Size : 12582784 (12.00 GiB 12.88 GB)
        #       Raid Devices : 2
        #      Total Devices : 2
        #        Persistence : Superblock is persistent
        #      Intent Bitmap : Internal
        #        Update Time : Tue Nov 16 11:06:16 2021
        #              State : clean 
        #     Active Devices : 2
        #    Working Devices : 2
        #     Failed Devices : 0
        #      Spare Devices : 0
        # Consistency Policy : bitmap
        #               Name : any:raid1sdab
        #               UUID : 8d05eb84:2de831d1:dfed54b2:ad592118
        #             Events : 216
        #     Number   Major   Minor   RaidDevice State
        #        0       8        0        0      active sync   /dev/sda
        #        1       8       16        1      active sync   /dev/sdb
        #
        # Example 'mdadm --misc --detail $raiddevice' output for a RAID CONTAINER with IMSM metadata
        # cf. https://github.com/rear/rear/pull/2702#issuecomment-968904230
        # /dev/md127:
        #            Version : imsm
        #         Raid Level : container
        #      Total Devices : 2
        #    Working Devices : 2
        #               UUID : 4d5cf215:80024c95:e19fdff4:2fba35a8
        #      Member Arrays : /dev/md/Volume0_0
        #     Number   Major   Minor   RaidDevice
        #        -       8        0        -        /dev/sda
        #        -       8       16        -        /dev/sdb
        #
        # /dev/md126:
        #          Container : /dev/md/imsm0, member 0
        #         Raid Level : raid1
        #         Array Size : 390706176 (372.61 GiB 400.08 GB)
        #      Used Dev Size : 390706176 (372.61 GiB 400.08 GB)
        #       Raid Devices : 2
        #      Total Devices : 2
        #              State : active
        #     Active Devices : 2
        #    Working Devices : 2
        #     Failed Devices : 0
        # Consistency Policy : resync
        #               UUID : ffb80762:127807b3:3d7e4f4d:4532022f
        #     Number   Major   Minor   RaidDevice State
        #        1       8       16        0      active sync   /dev/sdb
        #        0       8        0        1      active sync   /dev/sda
        line=( $( grep "Version :" $mdadm_details ) )
        metadata=${line[2]}
        line=( $( grep "Raid Level :" $mdadm_details ) )
        level=${line[3]}
        line=( $( grep "UUID :" $mdadm_details ) )
        uuid=${line[2]}
        line=( $( grep "Layout :" $mdadm_details ) )
        layout=${line[2]}
        # fix up layout for RAID10:
        # > near=2,far=1 -> n2
        if [ "$level" = "raid10" ] ; then
            OIFS=$IFS
            IFS=","
            for param in "$layout" ; do
                copies=${layout%=*}
                number=${layout#*=}
                if [ "$number" -gt 1 ] ; then
                    layout="${copies:0:1}$number"
                fi
            done
            IFS=$OIFS
        fi
        chunksize=$( grep "Chunk Size" $mdadm_details | tr -d " " | cut -d ":" -f "2" | sed -r 's/^([0-9]+).+/\1/')
        container=$( grep "Container" $mdadm_details | tr -d " " | cut -d ":" -f "2" | cut -d "," -f "1")
        line=( $( grep "Array Size :" $mdadm_details ) )
        array_size=${line[3]}
        line=( $( grep "Used Dev Size :" $mdadm_details ) )
        used_dev_size=${line[4]}
        line=( $( grep "Total Devices :" $mdadm_details ) )
        total_devices=${line[3]}
        line=( $( grep "Raid Devices :" $mdadm_details ) )
        raid_devices=${line[3]}
        if [[ "$raid_devices" ]] ; then
            let spare_devices=$total_devices-$raid_devices
        else
            let spare_devices=0
        fi

        component_devices=""
        let size=0
        if [[ "$container" ]] ; then
            component_devices=" devices=$( readlink -e $container )"
            if [[ "$used_dev_size" ]] ; then
                let size=$used_dev_size
            elif [[ "$array_size" ]] ; then
                let size=$array_size/$raid_devices
            fi
        else
            # Find all component devices
            # use the output of mdadm, but skip the array itself that is e.g. /dev/md127 or /dev/md/raid1sdab
            # sysfs has the information in RHEL 5+, but RHEL 4 lacks it.
            for component_device in $(  grep -o '/dev/.*' $mdadm_details | grep -v '/dev/md' | tr "\n" " " ) ; do
                component_device=$( get_device_name $component_device )
                if [ -z "$component_devices" ] ; then
                    component_devices=" devices=$component_device"
                else
                    component_devices+=",$component_device"
                fi
            done
        fi

        if [ "$size" -gt 0 ] ; then
            size=" size=$size"
        else
            size=""
        fi

        if [[ "$metadata" ]] ; then
            metadata=" metadata=$metadata"
        else
            metadata=""
        fi

        level=" level=$level"
        if [[ "$raid_devices" ]] && [ $raid_devices -gt 0 ] ; then
            raid_devices=" raid-devices=$raid_devices"
        elif [[ "$total_devices" ]] ; then
            raid_devices=" raid-devices=$total_devices"
        else
            raid_devices=""
        fi

        uuid=" uuid=$uuid"

        if [ "$spare_devices" -gt 0 ] ; then
            spare_devices=" spare-devices=$spare_devices"
        else
            spare_devices=""
        fi

        # mdadm can print '-unknown-' for a RAID layout
        # which got recently (2019-12-02) added to RAID0 (it existed before for RAID5 and RAID6 and RAID10) see
        # https://git.kernel.org/pub/scm/utils/mdadm/mdadm.git/commit/Detail.c?id=329dfc28debb58ffe7bd1967cea00fc583139aca
        # so we treat '-unknown-' same as an empty value to avoid that layout/prepare/GNU/Linux/120_include_raid_code.sh
        # will create a 'mdadm' command in diskrestore.sh like "mdadm ... --layout=-unknown- ..." which would fail
        # during "rear recover" with something like "mdadm: layout -unknown- not understood for raid0"
        # see https://github.com/rear/rear/issues/2616
        if test "$layout" -a '-unknown-' != "$layout" ; then
            layout=" layout=$layout"
        else
            layout=""
        fi

        if [ -n "$chunksize" ] ; then
            chunksize=" chunk=$chunksize"
        else
            chunksize=""
        fi

        if [[ "$name" ]] ; then
            name=" name=$name"
        else
            name=""
        fi

        echo "raid ${raiddevice}${metadata}${level}${raid_devices}${uuid}${name}${spare_devices}${layout}${chunksize}${component_devices}${size}"

        extract_partitions "$raiddevice"

    done < <( mdadm --detail --scan --config=partitions )

) >> $DISKLAYOUT_FILE

# mdadm is required in the recovery system if disklayout.conf contains at least one 'raid' entry
# see the create_raid function in layout/prepare/GNU/Linux/120_include_raid_code.sh
# what program calls are written to diskrestore.sh
# cf. https://github.com/rear/rear/issues/1963
grep -q '^raid ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( mdadm ) || true
grep -q '^raid ' $DISKLAYOUT_FILE && PROGS+=( mdmon ) || true
