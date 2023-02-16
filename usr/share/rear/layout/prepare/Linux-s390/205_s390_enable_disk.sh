# DASD disk device enablement for IBM Z (s390)
# Before we can compare or map DASD devices we must enable them.
# This operation is only needed during "rear recover".

DISK_MAPPING_HINTS=()

enable_s390_disk() {
    local keyword device bus len newname

    LogPrint "run chccwdev"
    while read len device bus ; do
        # this while loop must be outside the pipeline so that variables propagate outside
        # (pipelines run in subshells)
        LogPrint "Enabling DASD $device with virtual device number $bus"
        if chccwdev -e $bus ; then
            newname=$(lsdasd $bus | awk "/$bus/ { print \$3}" )
            if ! test $newname ; then
                LogPrintError "New device with virtual device number $bus not found among online DASDs"
                continue
            fi
            if [ "$newname" != "$device" ]; then
                LogPrint "original DASD '$device' changed name to '$newname'"
                test "$MIGRATION_MODE" || MIGRATION_MODE='true'
            fi
            DISK_MAPPING_HINTS+=( "/dev/$device /dev/$newname" )
        else
            LogPrintError "Failed to enable $bus"
        fi
    done < <( grep "^dasd_channel " "$LAYOUT_FILE" | while read keyword bus device; do
                  # add device name length, so that "dasdb" sorts properly before "dasdaa"
                  # we need to create devices in the same order as the kernel orders them (by minor number)
                  # - this increases the chance that they will get identical names
                  echo ${#device} $device $bus
                  done | sort -k1n -k2 )
}

# May need to look at $OS_VENDOR also as DASD disk layout is distro specific:
case $OS_MASTER_VENDOR in
    (SUSE|Fedora|Debian)
        # "Fedora" also handles Red Hat
        # "Debian" also handles Ubuntu
        enable_s390_disk
        ;;
    (*)
        LogPrintError "No code for DASD disk device enablement on $OS_MASTER_VENDOR"
        ;;
esac
