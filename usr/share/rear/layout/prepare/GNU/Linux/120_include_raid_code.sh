# Code to recreate a software RAID configuration.

if ! has_binary mdadm; then
    return
fi

# Test for features of mdadm.
# True if mdadm supports uuid restoration.
FEATURE_MDADM_UUID=

# Test for the mdadm version, version gets printed on stderr.
mdadm_version=$(get_version mdadm --version)

[ "$mdadm_version" ]
BugIfError "Function get_version could not detect mdadm version."

if version_newer "$mdadm_version" 2.0 ; then
    FEATURE_MDADM_UUID="y"
fi

# List of raid devices we already encountered
raid_devices=()

create_raid() {
    local raid device options
    read raid device options < <(grep "^raid $1 " "$LAYOUT_FILE")

    local mdadmcmd="mdadm --create $device --force"

    local devices_total=0
    local devices=()
    local option
    for option in $options ; do
        case "$option" in
            (devices=*)
                local list=${option#devices=}
                OIFS=$IFS
                IFS=","
                local raiddevice
                for raiddevice in $list ; do
                    devices+=($raiddevice)
                done
                IFS=$OIFS
                ;;
            (uuid=*)
                if [ -n "$FEATURE_MDADM_UUID" ] ; then
                    mdadmcmd="$mdadmcmd --$option"
                fi
                ;;
            (raid-devices=*)
                devices_total=${option#raid-devices=}
                mdadmcmd="$mdadmcmd --$option"
                ;;
            (*)
                mdadmcmd="$mdadmcmd --$option"
                ;;
        esac
    done

    # If some devices are missing, add 'missing' special devices
    if [ ${#devices[@]} -lt $devices_total ] ; then
        # Don't consider raid inside a container (it's expected to have 1 device only: the container)
        if [ ${#devices[@]} -ne 1 ] || ! IsInArray ${devices[0]} "${raid_devices[@]}" ; then
            # Print as many 'missing' as there are missing devices
            let missing=$devices_total-${#devices[@]}
            LogPrint "Software RAID $device has not enough physical devices, adding $missing 'missing' devices"
            devices="$devices $(printf "missing%.0s " $(seq $missing))"
        fi
    fi

    raid_devices+=( $device )

    # Try to make mdadm non-interactive...
    mdadmcmd="echo \"Y\" | $mdadmcmd ${devices[@]}"

    cat >> "$LAYOUT_CODE" <<EOF

#
# Code handling Software Raid '$device'
#

LogPrint "Creating software RAID $device"
test -b $device && mdadm --stop $device

for dev in ${devices[@]}; do
    wipefs -a \$dev
done

$mdadmcmd >&2
EOF

    ### Create partitions on MD (if any).
    # 'label' argument is not specified here because we don't know (there may
    # be none), but it will be computed automatically by create_partitions.
    create_partitions "$device"

    cat >> "$LAYOUT_CODE" <<EOF

# Make sure device nodes are visible (eg. in RHEL4)
my_udevtrigger
my_udevsettle

# Clean up transient partitions and resize shrinked ones
delete_dummy_partitions_and_resize_real_ones

#
# End of code handling Software Raid '$device'
#

EOF
}
