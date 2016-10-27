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

    local devices=""
    local option
    for option in $options ; do
        case "$option" in
            (devices=*)
                list=${option#devices=}
                OIFS=$IFS
                IFS=","
                for raiddevice in $list ; do
                    devices="$devices$raiddevice "
                done
                IFS=$OIFS
                ;;
            (uuid=*)
                if [ -n "$FEATURE_MDADM_UUID" ] ; then
                    mdadmcmd="$mdadmcmd --$option"
                fi
                ;;
            (*)
                mdadmcmd="$mdadmcmd --$option"
                ;;
        esac
    done
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
