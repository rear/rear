
# Code to recreate a software RAID configuration.

# Nothing to do when there is no mdadm command:
has_binary mdadm || return 0

# For example 'mdadm --detail --scan --config=partitions' output looks like
# ARRAY /dev/md/raid1sdab metadata=1.0 name=any:raid1sdab UUID=8d05eb84:2de831d1:dfed54b2:ad592118
# for a RAID1 array and for a RAID CONTAINER with IMSM metadata it looks like
# ARRAY /dev/md/imsm0 metadata=imsm UUID=4d5cf215:80024c95:e19fdff4:2fba35a8
# ARRAY /dev/md/Volume0_0 container=/dev/md/imsm0 member=0 UUID=ffb80762:127807b3:3d7e4f4d:4532022f
#
# For the 'mdadm --detail --scan --config=partitions' examples above 'raid' entries in disklayout.conf look like
# raid /dev/md127 level=raid1 raid-devices=2 devices=/dev/sda,/dev/sdb name=raid1sdab metadata=1.0 uuid=8d05eb84:2de831d1:dfed54b2:ad592118
# for a RAID1 array and for a RAID CONTAINER with IMSM metadata it looks like
# raid /dev/md127 metadata=imsm level=container raid-devices=2 uuid=4d5cf215:80024c95:e19fdff4:2fba35a8 name=imsm0 devices=/dev/sda,/dev/sdb
# raid /dev/md126 level=raid1 raid-devices=2 uuid=ffb80762:127807b3:3d7e4f4d:4532022f name=Volume0_0 devices=/dev/md127 size=390706176
# cf. layout/save/GNU/Linux/210_raid_layout.sh
# and the matching 'part' entries in disklayout.conf look like
# part /dev/md127 10485760 1048576 rear-noname bios_grub /dev/md127p1
# part /dev/md127 12739067392 11534336 rear-noname none /dev/md127p2
# for a RAID1 array and for a RAID CONTAINER with IMSM metadata it looks like
# part /dev/md126 629145600 1048576 EFI%20System%20Partition boot,esp /dev/md126p1
# part /dev/md126 1073741824 630194176 md126p2 none /dev/md126p2
# part /dev/md126 398378139648 1703936000 md126p3 lvm /dev/md126p3
# cf. https://github.com/rear/rear/pull/2702#issuecomment-968904230

# List of raid devices for which create_raid was already done
# i.e. those raid devices for which there is already code in diskrestore.sh
# but those raid devices are not yet created (they are created after diskrestore.sh was run).
# This global variable is set and used in each call of create_raid().
# This global variable is initialized here only once when this script is run:
CREATE_RAID_DEVICES_CODE=()

create_raid() {
    local raid raiddevice options
    read raid raiddevice options < <(grep "^raid $1 " "$LAYOUT_FILE")

    local mdadmcmd="mdadm --create $raiddevice --force"

    local raid_devices=0
    local component_devices=()
    local option
    for option in $options ; do
        case "$option" in
            (devices=*)
                # E.g. when option is "devices=/dev/sda,/dev/sdb,/dev/sdc"
                # then ${option#devices=} is "/dev/sda,/dev/sdb,/dev/sdc"
                # so that echo ${option#devices=} | tr ',' ' '
                # results "/dev/sda /dev/sdb /dev/sdc"
                component_devices=( $( echo ${option#devices=} | tr ',' ' ' ) )
                ;;
            (raid-devices=*)
                raid_devices=${option#raid-devices=}
                mdadmcmd+=" --$option"
                ;;
            (*)
                mdadmcmd+=" --$option"
                ;;
        esac
    done

    # If some devices are missing, add 'missing' special devices
    local component_devices_count=${#component_devices[@]}
    local missing_devices_count=$(( raid_devices - component_devices_count ))
    if test $missing_devices_count -gt 0 ; then
        # Don't consider raid inside a container (it's expected to have 1 device only: the container)
        if [ $component_devices_count -ne 1 ] || ! IsInArray ${component_devices[0]} "${CREATE_RAID_DEVICES_CODE[@]}" ; then
            LogPrint "Software RAID $raiddevice has not enough component devices, adding $missing_devices_count 'missing' devices"
            # Print as many 'missing' as there are missing devices
            # cf. https://stackoverflow.com/questions/54396599/bash-printf-how-to-understand-zero-dot-s-0-s-syntax
            # that reads (excerpts)
            #  "when the width is 0, then the field is not printed at all
            #   if there are more arguments than fields, printf repeats the format"
            component_devices+=( $( printf "missing%.0s " $( seq $missing_devices_count ) ) )
        fi
    fi

    CREATE_RAID_DEVICES_CODE+=( $raiddevice )

    # Try to make mdadm non-interactive:
    mdadmcmd="echo Y | $mdadmcmd ${component_devices[@]}"

    cat >> "$LAYOUT_CODE" <<EOF
#
# Code handling Software RAID $raiddevice
#
LogPrint "Creating software RAID $raiddevice"
test -b $raiddevice && mdadm --stop $raiddevice
for component_device in ${component_devices[@]} ; do
    wipefs -a \$component_device
done
$mdadmcmd >&2
EOF

    # Create partitions on RAID device (if any).
    # 'label' argument is not specified here because we don't know (there may be none),
    # but it will be computed automatically by create_partitions.
    create_partitions "$raiddevice"

    cat >> "$LAYOUT_CODE" <<EOF
# Make sure device nodes are visible (eg. in RHEL4)
my_udevtrigger
my_udevsettle
# Clean up transient partitions and resize shrinked ones
delete_dummy_partitions_and_resize_real_ones
#
# End of code handling Software RAID $raiddevice
#
EOF
}
