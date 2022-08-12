
# Save the Software RAID layout

# Nothing to do when there is no /proc/mdstat
test -e /proc/mdstat || return 0

# Nothing to do when /proc/mdstat does not contain "blocks"
grep -q blocks /proc/mdstat || return 0

Log "Saving Software RAID configuration"

# Have 'mdadm --detail --scan --config=partitions' output as comment in disklayout.conf:
( echo "Software RAID devices (mdadm --detail --scan --config=partitions)" ; mdadm --detail --scan --config=partitions ) | grep -v '^$' | sed -e 's/^/# /' >>$DISKLAYOUT_FILE

local array raiddevice junk
local basename
local line
local metadata level raid_devices uuid name spare_devices layout chunksize component_devices container_size
local container array_size
local layout_option layout_option_name layout_option_value layout_option_setting
local component_device
local raid_layout_entry
local raid_dev_size raid_dev_label
local mdadm_exit_code

# Read 'mdadm --detail --scan --config=partitions' output which looks like
# ARRAY /dev/md/raid1sdab metadata=1.0 name=any:raid1sdab UUID=8d05eb84:2de831d1:dfed54b2:ad592118
# for a RAID1 array and for a RAID CONTAINER with IMSM metadata it looks like
# ARRAY /dev/md/imsm0 metadata=imsm UUID=4d5cf215:80024c95:e19fdff4:2fba35a8
# ARRAY /dev/md/Volume0_0 container=/dev/md/imsm0 member=0 UUID=ffb80762:127807b3:3d7e4f4d:4532022f
# cf. https://github.com/rear/rear/pull/2702#issuecomment-968904230
#
# For reasoning why
# COMMAND | while read ... do ... done
# is usually better than
# while read ... do ... done < <( COMMAND )
# see layout/save/GNU/Linux/220_lvm_layout.sh

mdadm --detail --scan --config=partitions | while read array raiddevice junk ; do

    # Skip if it is not an "ARRAY":
    test "$array" = "ARRAY" || continue

    # 'raidarray' entries in disklayout.conf look like (cf. the 'mdadm --detail --scan --config=partitions' examples above)
    # raidarray /dev/md127 metadata=1.0 level=raid1 raid-devices=2 uuid=8d05eb84:2de831d1:dfed54b2:ad592118 name=raid1sdab devices=/dev/sda,/dev/sdb
    # for a RAID1 array and for a RAID CONTAINER with IMSM metadata it looks like
    # raidarray /dev/md127 metadata=imsm level=container raid-devices=2 uuid=4d5cf215:80024c95:e19fdff4:2fba35a8 name=imsm0 devices=/dev/sda,/dev/sdb
    # raidarray /dev/md126 level=raid1 raid-devices=2 uuid=ffb80762:127807b3:3d7e4f4d:4532022f name=Volume0_0 devices=/dev/md127 size=390706176
    # cf. https://github.com/rear/rear/pull/2702#issuecomment-968904230
    # Each 'raidarray' entry in disklayout.conf starts with the keyword 'raidarray':
    raid_layout_entry="raidarray"

    # Do not use an array name from a previous run of the while loop:
    name=""
    basename=${raiddevice##*/}
    # When raiddevice is a symlink like /dev/md/raid1sdab -> /dev/md127
    # Use the kernel device node and set the array name to the symlink's basename:
    if test -h $raiddevice ; then
        raiddevice=$( readlink -e $raiddevice )
        name=$basename
    fi
    test -b "$raiddevice" && raid_layout_entry+=" $raiddevice" || Error "RAID device '$raiddevice' is no block device"

    # We use the detailed mdadm output quite a lot so run the mdadm command only once:
    mdadm_details="$TMP_DIR/mdraid.$basename"
    mdadm --misc --detail $raiddevice | grep -v '^$' > $mdadm_details

    # Have 'mdadm --misc --detail $raiddevice' output as comment in disklayout.conf:
    ( echo "Software RAID $name device $raiddevice (mdadm --misc --detail $raiddevice)" ; cat $mdadm_details ) | sed -e 's/^/# /' >>$DISKLAYOUT_FILE

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

    # doc/user-guide/06-layout-configuration.adoc reads
    #   Disk layout file syntax
    #   Software RAID
    #   raidarray /dev/<kernel RAID device> level=<RAID level> raid-devices=<nr of active devices> devices=<component device1,component device2,...> [name=<array name>] [metadata=<metadata style>] [uuid=<UUID>] [layout=<data layout>] [chunk=<chunk size>] [spare-devices=<nr of spare devices>] [size=<container size>]
    # so the mdadm options --level --raid-devices and the component-devices are mandatory:

    line=( $( grep "Raid Level :" $mdadm_details ) )
    level=${line[3]}
    # A RAID level that is more than one word would make 'read' fail for this 'raidarray' entry in disklayout.conf
    test $level || Error "RAID $raiddevice level '$level' is not a single word"
    raid_layout_entry+=" level=$level"

    line=( $( grep "Raid Devices :" $mdadm_details ) )
    raid_devices=${line[3]}
    line=( $( grep "Total Devices :" $mdadm_details ) )
    total_devices=${line[3]}
    if test $raid_devices && test $raid_devices -gt 0 ; then
        raid_layout_entry+=" raid-devices=$raid_devices"
    elif test $total_devices && test $total_devices -gt 0 ; then
        raid_layout_entry+=" raid-devices=$total_devices"
    else
        Error "Neither number of active devices nor number of total devices is greater than 0 for RAID $raiddevice"
    fi

    container=$( grep "Container" $mdadm_details | tr -d " " | cut -d ":" -f "2" | cut -d "," -f "1")
    line=( $( grep "Used Dev Size :" $mdadm_details ) )
    used_dev_size=${line[4]}
    line=( $( grep "Array Size :" $mdadm_details ) )
    array_size=${line[3]}
    if test "$container" ; then
        component_devices=" devices=$( readlink -e $container )"
        if test "$used_dev_size" ; then
            container_size=$used_dev_size
        elif test "$array_size" ; then
            container_size=$(( array_size / raid_devices ))
        fi
    else
        # Find all component devices
        # use the output of mdadm, but skip the array itself that is e.g. /dev/md127 or /dev/md/raid1sdab
        # sysfs has the information in RHEL 5+, but RHEL 4 lacks it.
        component_devices=""
        for component_device in $(  grep -o '/dev/.*' $mdadm_details | grep -v '/dev/md' | tr "\n" " " ) ; do
            component_device=$( get_device_name $component_device )
            test -b "$component_device" || Error "RAID $raiddevice component device '$component_device' is no block device"
            # A component device that is more than one word would make 'read' fail for this 'raidarray' entry in disklayout.conf
            test $component_device || Error "RAID $raiddevice component device '$component_device' is not a single word"
            # Have the component devices string as "first_component_device,second_component_device,..."
            test $component_devices && component_devices+=",$component_device" || component_devices="$component_device"
        done
    fi
    test $component_devices && raid_layout_entry+=" devices=$component_devices" || Error "No component devices for RAID $raiddevice"

    # Optional mdadm option settings:
    test $name && raid_layout_entry+=" name=$name"

    line=( $( grep "Version :" $mdadm_details ) )
    metadata=${line[2]}
    test $metadata && raid_layout_entry+=" metadata=$metadata"

    line=( $( grep "UUID :" $mdadm_details ) )
    uuid=${line[2]}
    test $uuid && raid_layout_entry+=" uuid=$uuid"

    # A "Layout :" line in the detailed mdadm output normally looks like
    #          Layout : near=2
    #          Layout : far=3
    #          Layout : offset=4
    # cf. https://github.com/rear/rear/pull/2768#issuecomment-1072362485
    # and https://github.com/rear/rear/pull/2768#issuecomment-1072361069
    # but it might also look like
    #          Layout : near=2, far=3
    # or it might even look like (regardless that this was never seen in practice)
    #          Layout : near=2, far=3, offset=4
    # cf. https://linux-blog.anracom.com/tag/far-layout/
    # and https://unix.stackexchange.com/questions/280283/is-it-possible-to-create-a-mdadm-raid10-with-both-near-and-far-layout-options
    # and https://ubuntuforums.org/showthread.php?t=1689828&page=4
    # For the above examples the line array becomes ("declare -p line" outputs):
    # declare -a line=([0]="Layout" [1]=":" [2]="near=2")
    # declare -a line=([0]="Layout" [1]=":" [2]="far=3")
    # declare -a line=([0]="Layout" [1]=":" [2]="offset=4")
    # declare -a line=([0]="Layout" [1]=":" [2]="near=2," [3]="far=3")
    # declare -a line=([0]="Layout" [1]=":" [2]="near=2," [3]="far=3," [4]="offset=4")
    line=( $( grep "Layout :" $mdadm_details ) )
    # We use ${line[3]:-} and ${line[4]:-} to be safe against things like
    # "bash: line[3]: unbound variable" in case of 'set -eu'
    # so for the above examples the layout string becomes:
    # near=2
    # far=3
    # offest=4
    # near=2,far=3
    # near=2,far=3,offset=4
    layout="${line[2]}${line[3]:-}${line[4]:-}"
    # For RAID10 have the layout value what the mdadm command needs as --layout option value
    # so with the above examples the mdadm command option --layout=... value has to become
    # near=2                -> n2
    # far=3                 -> f3
    # offset=4              -> o4
    # near=2,far=3          -> n2
    # near=2,far=3,offset=4 -> n2
    # TODO: Currently if there is more than one RAID10 layout value only the first one is used because according to
    # https://unix.stackexchange.com/questions/280283/is-it-possible-to-create-a-mdadm-raid10-with-both-near-and-far-layout-options
    # it seems it is not possible (or it does not make sense in practice) to set both "near=..." and "far=..."
    # and we also assume it is not possible (or it does not make sense in practice) to set more than one RAID10 layout value.
    if test "$level" = "raid10" ; then
        layout_option_setting=""
        OIFS=$IFS
        IFS=","
        for layout_option in $layout ; do
            # When a RAID10 layout option is already set for this RAID array an additional one is not supported:
            if test $layout_option_setting ; then
                LogPrintError "Ignoring additional RAID10 layout '$layout_option' for $raiddevice (only one RAID10 layout setting is supported)"
                continue
            fi
            layout_option_name=${layout_option%=*}
            layout_option_value=${layout_option#*=}
            # The RAID10 layout option value must be "a small number" where "2 is normal, 3 can be useful"
            # according to "man mdadm" (of mdadm v4.1 in openSUSE Leap 15.3).
            # This test also fails when the RAID10 layout option value is not a number:
            if ! test $layout_option_value -gt 0 ; then
                LogPrintError "Ignoring RAID10 layout '$layout_option' for $raiddevice (the value is not at least 1)"
                continue
            fi
            # Now the RAID10 layout option value is at least a number:
            if ! test $layout_option_value -le 9 ; then
                LogPrintError "Ignoring RAID10 layout '$layout_option' for $raiddevice (the value is not a small number)"
                continue
            fi
            # Save the RAID10 layout option with the right syntax for the mdadm --layout option value during "rear recover":
            case "$layout_option_name" in
                (near)
                    layout_option_setting="n$layout_option_value"
                    ;;
                (far)
                    layout_option_setting="f$layout_option_value"
                    ;;
                (offset)
                    layout_option_setting="o$layout_option_value"
                    ;;
                (*)
                    LogPrintError "Ignoring RAID10 layout '$layout_option' for $raiddevice (only 'near' 'far' and 'offset' are valid)"
                    ;;
            esac
        done
        IFS=$OIFS
        # Ensure $layout_option_setting is a single non empty and non blank word
        # (no quoting because test " " returns zero exit code):
        test $layout_option_setting && layout="$layout_option_setting" || layout=""
    fi
    # mdadm can print '-unknown-' for a RAID layout
    # which got recently (2019-12-02) added to RAID0 (it existed before for RAID5 and RAID6 and RAID10) see
    # https://git.kernel.org/pub/scm/utils/mdadm/mdadm.git/commit/Detail.c?id=329dfc28debb58ffe7bd1967cea00fc583139aca
    # so we treat '-unknown-' same as an empty value to avoid that layout/prepare/GNU/Linux/120_include_raid_code.sh
    # will create a 'mdadm' command in diskrestore.sh like "mdadm ... --layout=-unknown- ..." which would fail
    # during "rear recover" with something like "mdadm: layout -unknown- not understood for raid0"
    # see https://github.com/rear/rear/issues/2616
    # and ensure $layout is a single non empty and non blank word
    # (no quoting because test " " returns zero exit code)
    # and 'test ... && test ...' instead of 'test ... -a ...' to avoid a bash error message
    # because when $layout is blank or empty test $layout -a '-unknown-' != "$layout"
    # becomes test -a '-unknown-' != ""
    # which results "bash: test: too many arguments"
    # cf. https://github.com/rear/rear/pull/2768#discussion_r843740413
    test $layout && test '-unknown-' != "$layout" && raid_layout_entry+=" layout=$layout"

    chunksize=$( grep "Chunk Size" $mdadm_details | tr -d " " | cut -d ":" -f "2" | sed -r 's/^([0-9]+).+/\1/')
    test $chunksize && raid_layout_entry+=" chunk=$chunksize"

    spare_devices=""
    test $raid_devices && spare_devices=$(( total_devices - raid_devices ))
    test $spare_devices -gt 0 && raid_layout_entry+=" spare-devices=$spare_devices"

    test $container_size -gt 0 && raid_layout_entry+=" size=$container_size"

    echo "# RAID device $raiddevice" >>$DISKLAYOUT_FILE
    echo "# Format: raidarray /dev/<kernel RAID device> level=<RAID level> raid-devices=<nr of active devices> devices=<component device1,component device2,...> [name=<array name>] [metadata=<metadata style>] [uuid=<UUID>] [layout=<data layout>] [chunk=<chunk size>] [spare-devices=<nr of spare devices>] [size=<container size>]" >>$DISKLAYOUT_FILE
    echo "$raid_layout_entry" >>$DISKLAYOUT_FILE

    # cf. the code in layout/save/GNU/Linux/200_partition_layout.sh
    # $raiddevice is e.g. /dev/md127
    raid_dev_size=$( get_disk_size ${raiddevice#/dev/} )
    raid_dev_label=$( parted -s $raiddevice print | grep -E "Partition Table|Disk label" | cut -d ":" -f "2" | tr -d " " )
    echo "# RAID disk $raiddevice" >>$DISKLAYOUT_FILE
    echo "# Format: raiddisk <devname> <size(bytes)> <partition label type>" >>$DISKLAYOUT_FILE
    echo "raiddisk $raiddevice $raid_dev_size $raid_dev_label" >>$DISKLAYOUT_FILE

    # extract_partitions is run as a separated process (in a subshell)
    # because it runs in the "mdadm ... | while read ... ; do ... done" pipe
    # so things only work here if extract_partitions does not set variables
    # that are meant to be used outside of this pipe, check extract_partitions()
    # in layout/save/GNU/Linux/200_partition_layout.sh
    echo "# Partitions on $raiddevice" >>$DISKLAYOUT_FILE
    echo "# Format: part <device> <partition size(bytes)> <partition start(bytes)> <partition type|name> <flags> /dev/<partition>" >>$DISKLAYOUT_FILE
    extract_partitions "$raiddevice" >>$DISKLAYOUT_FILE

done
# Check the exit code of "mdadm --detail --scan --config=partitions"
# in the "mdadm --detail --scan --config=partitions | while read ... ; do ... done" pipe
# cf. layout/save/GNU/Linux/220_lvm_layout.sh
mdadm_exit_code=${PIPESTATUS[0]}
test $mdadm_exit_code -eq 0 || Error "'mdadm --detail --scan --config=partitions' failed with exit code $mdadm_exit_code"

# mdadm is required in the recovery system if disklayout.conf contains at least one 'raidarray' entry
# see the create_raidarray function in layout/prepare/GNU/Linux/120_include_raid_code.sh
# what program calls are written to diskrestore.sh
# cf. https://github.com/rear/rear/issues/1963
if grep -q '^raidarray ' $DISKLAYOUT_FILE ; then
    REQUIRED_PROGS+=( mdadm )
    # mdmon was added via https://github.com/rear/rear/pull/2702
    PROGS+=( mdmon )
fi
