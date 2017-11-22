
# Compare disks from the original system to this system.
# This implements some basic autodetection during "rear recover"
# when disks on the replacement hardware seem to not match compared to
# what there was stored in disklayout.conf on the original system.
# If a mismatch is autodetected then ReaR goes into its
# MIGRATION_MODE where it asks via user dialogs what to do.

if is_true "$MIGRATION_MODE" ; then
    LogPrint "Enforced manual disk layout configuration (MIGRATION_MODE is 'true')"
    return
fi

if is_false "$MIGRATION_MODE" ; then
    LogPrint "Enforced restoring disk layout as specified in '$LAYOUT_FILE' (MIGRATION_MODE is 'false')"
    return
fi

LogPrint "Comparing disks"

while read disk dev size junk ; do
    dev=$( get_sysfs_name $dev )
    Log "Comparing $dev"
    if test -e "/sys/block/$dev" ; then
        Log "Device /sys/block/$dev exists"
        newsize=$( get_disk_size $dev )
        if test "$newsize" -eq "$size" ; then
            LogPrint "Device $dev has expected size $size (will be used for restore)"
        else
            LogPrint "Device $dev has size $newsize but $size is expected (needs manual configuration)"
            MIGRATION_MODE='true'
        fi
    else
        LogPrint "Device $dev does not exist (manual configuration needed)"
        MIGRATION_MODE='true'
    fi
done < <( grep -E '^disk |^multipath ' "$LAYOUT_FILE" )

if is_true "$MIGRATION_MODE" ; then
    LogPrint "Switching to manual disk layout configuration"
else
    LogPrint "Disk configuration looks identical"
    # See https://github.com/rear/rear/issues/1271
    # why the above autodetection is not safe.
    # To be more on the safe side a user confirmation dialog is shown here
    # with a relatively short timeout to avoid too much delay by default
    # so that the user could intervene and enforce MIGRATION_MODE:
    prompt="Proceed with restore (yes) otherwise manual disk layout configuration is enforced"
    input_value=""
    wilful_input=""
    input_value="$( UserInput -I DISK_LAYOUT_PROCEED_RESTORE -t 10 -p "$prompt" -D 'yes' )" && wilful_input="yes" || wilful_input="no"
    if is_true "$input_value" ; then
        is_true "$wilful_input" && LogPrint "User confirmed to proceed with restore" || LogPrint "Proceeding with restore by default"
    else
        # The user enforced MIGRATION_MODE uses the special 'TRUE' value in upper case letters
        # that is needed to overrule the prepare/default/270_overrule_migration_mode.sh script:
        MIGRATION_MODE='TRUE'
        LogPrint "User enforced manual disk layout configuration"
    fi
fi

