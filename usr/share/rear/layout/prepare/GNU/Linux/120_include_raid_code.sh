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

create_raid() {
    local raid device options
    read raid device options < <(grep "^raid $1 " "$LAYOUT_FILE")

    local mdadmcmd="mdadm --create $device --force"

    local devices_total=0
    local devices_found=0
    local devices=""
    local option
    for option in $options ; do
        case "$option" in
            (devices=*)
                local list=${option#devices=}
                OIFS=$IFS
                IFS=","
                local raiddevice
                for raiddevice in $list ; do
                    devices="$devices$raiddevice "
                    let devices_found+=1
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
    if [ $devices_found -lt $devices_total ] ; then
        # Print as many 'missing' as there are missing devices
        let missing=$devices_total-$devices_found
        LogPrint "Software RAID $device has not enough physical devices, adding $missing 'missing' devices"
        devices="$devices $(printf "missing%.0s " $(seq $missing))"
    fi

    # Try to make mdadm non-interactive...
    mdadmcmd="echo \"Y\" | $mdadmcmd $devices"

cat <<EOF >> "$LAYOUT_CODE"
LogPrint "Creating software RAID $device"
test -b $device && mdadm --stop $device

$mdadmcmd >&2
EOF

    ### Create partitions on MD.
    create_partitions "$device"
}
