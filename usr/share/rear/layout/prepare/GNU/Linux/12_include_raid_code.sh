# Code to recreate a software RAID configuration

if ! type -p mdadm &>/dev/null ; then
    return
fi

# Test for features in mdadm
# true if mdadm supports uuid restoration
FEATURE_MDADM_UUID=

# Test for the mdadm version, version gets printed on stderr
mdadm_version=$(get_version mdadm --version)

if [ -z "$mdadm_version" ]; then
    BugError "Function get_version could not detect mdadm version."
elif version_newer "$mdadm_version" 2.0 ; then
    FEATURE_MDADM_UUID="y"
fi

create_raid() {
    read raid device options < $1

    mdadmcmd="mdadm --create $device"

    devices=""
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
    mdadmcmd="echo \"Y\" | $mdadmcmd --force $devices"

cat <<EOF >> $LAYOUT_CODE
LogPrint "Creating software RAID $device"
test -b $device && mdadm --stop $device

$mdadmcmd 1>&2
EOF
}
