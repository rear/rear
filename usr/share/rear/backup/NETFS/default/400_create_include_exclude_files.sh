
# What to include in the backup:
cat /dev/null > "$TMP_DIR/backup-includes.txt"

# First by default backup the mounted filesystems in disklayout.conf
# (except BACKUP_ONLY_INCLUDE or MANUAL_INCLUDE is set)
# as defined in var/lib/rear/recovery/mountpoint_device which contains at least '/'
# where usually '/' is first because "fs ... /" is first in disklayout.conf
# see usr/share/rear/layout/save/default/340_generate_mountpoint_device.sh
# so the basic system files and directories get stored first in the backup
# see https://github.com/rear/rear/pull/3177#issuecomment-1985926458
# and https://github.com/rear/rear/issues/3217#issue-2277985295
if ! is_true "$BACKUP_ONLY_INCLUDE" ; then
    if [ "${MANUAL_INCLUDE:-NO}" != "YES" ] ; then
        # Add the mountpoints that will be recovered to the backup include list unless a mountpoint is excluded.
        # This looks contradicting because "mountpoints that will be recovered" should not be excluded via EXCLUDE_MOUNTPOINTS
        # which excludes filesystems from being recreated by specifying their mountpoints (see EXCLUDE_MOUNTPOINTS in default.conf)
        # so we report suspicious cases as LogPrintError to have the user at least informed:
        while read mountpoint device junk ; do
            if IsInArray "$mountpoint" "${EXCLUDE_MOUNTPOINTS[@]}" ; then
                LogPrintError "Mountpoint '$mountpoint' in $VAR_DIR/recovery/mountpoint_device is excluded in EXCLUDE_MOUNTPOINTS"
                continue
            fi
            if ! mountpoint "$mountpoint" ; then
                LogPrintError "Mountpoint '$mountpoint' in $VAR_DIR/recovery/mountpoint_device is not a mountpoint"
                continue
            fi
            echo "$mountpoint" >> "$TMP_DIR/backup-includes.txt"
        done < "$VAR_DIR/recovery/mountpoint_device"
    fi
fi

# Then also backup all that is explicitly specified in BACKUP_PROG_INCLUDE:
for backup_include_item in "${BACKUP_PROG_INCLUDE[@]}" ; do
    test "$backup_include_item" || continue
    echo "$backup_include_item" >> "$TMP_DIR/backup-includes.txt"
done

# backup-include.txt is backup-includes.txt without duplicates but keeps the ordering
# in particular when the user may have specified something in BACKUP_PROG_INCLUDE
# which also gets backed up by the default backup of the mounted local filesystems
# to avoid possibly unwanted and unexpected subtle consequences
# see https://github.com/rear/rear/pull/3175#issuecomment-1985382738
unique_unsorted "$TMP_DIR/backup-includes.txt" > "$TMP_DIR/backup-include.txt"

# Verify that at least '/' is in backup-include.txt
# because ReaR is meant to recreate a system so at least
# the basic system files in the root filesystem must be backed up
# when "rear mkbackup" is used which is meant to backup at least the basic system.
# Examples how '/' could be missing in backup-include.txt when "rear mkbackup" is used:
# - When BACKUP_ONLY_INCLUDE or MANUAL_INCLUDE is set
#   the user may not have added '/' to BACKUP_PROG_INCLUDE
#   so the '/' mountpoint will not be written into backup-include.txt
# - When '/' is on a multipath device the default AUTOEXCLUDE_MULTIPATH=y
#   will automatically exclude '/' and dependent components
#   so '/' is not in var/lib/rear/recovery/mountpoint_device
#   see https://github.com/rear/rear/issues/3189#issuecomment-2082747052
#   and https://github.com/rear/rear/issues/3189#issuecomment-2082981807
#   so that the above default backup of the mounted local filesystems
#   will not write the '/' mountpoint into backup-include.txt
# See https://github.com/rear/rear/issues/3217
# A different use case is "rear mkbackuponly" which can be used
# to backup the (basic) system without creating a rescue medium
# but "rear mkbackuponly" can also be used to only backup something else
# in particular via "rear -C something_else_backup mkbackuponly"
# as documented in doc/user-guide/11-multiple-backups.adoc
# cf. https://github.com/rear/rear/pull/3221#issuecomment-2129240645
# So in case of the mkbackuponly workflow we must not error out
# but (in verbose mode) we inform the user to be more on the safe side:
if ! grep -q '^/$' "$TMP_DIR/backup-include.txt" ; then
    if test "$WORKFLOW" = "mkbackuponly" ; then
        LogPrint "The root filesystem is not backed up (no '/' in $TMP_DIR/backup-include.txt)"
    else
        Error "At least the root filesystem must be backed up (no '/' in $TMP_DIR/backup-include.txt)"
    fi
fi

# What to exclude from the backup:
cat /dev/null > "$TMP_DIR/backup-excludes.txt"

# First exclude all that is specified to be excluded from the backup via BACKUP_PROG_EXCLUDE:
for backup_exclude_item in "${BACKUP_PROG_EXCLUDE[@]}" ; do
    test "$backup_exclude_item" || continue
    echo "$backup_exclude_item" >> "$TMP_DIR/backup-excludes.txt"
done

# Then also add filesystems that are specified to be excluded from being recreated via their mountpoints
# to the backup exclude list (see EXCLUDE_MOUNTPOINTS in default.conf)
# except BACKUP_ONLY_EXCLUDE is set:
if ! is_true "$BACKUP_ONLY_EXCLUDE" ; then
    for excluded_mountpoint in "${EXCLUDE_MOUNTPOINTS[@]}" ; do
        if ! mountpoint "$excluded_mountpoint" ; then
            LogPrintError "Mountpoint '$excluded_mountpoint' in EXCLUDE_MOUNTPOINTS is no mountpoint"
            continue
        fi
        echo "$excluded_mountpoint/" >> "$TMP_DIR/backup-excludes.txt"
    done
fi

# backup-exclude.txt is backup-excludes.txt without duplicates but keeps the ordering:
unique_unsorted "$TMP_DIR/backup-excludes.txt" > "$TMP_DIR/backup-exclude.txt"
