# remove existing disk-by-id mappings
# FIXME: Don't we actually not 'remove' but 'replace' or 'migrate' disk-by-id mappings?
#
# We call sed once for each substituation
# it would be better to build one sed script and use this later
#  (like finalize/GNU/Linux/250_migrate_disk_devices_layout.sh)
#
# OLD_ID_FILE contains entries like these (last 2 lines are multipath targets)
# dm-name-rootvg-lv_swap /dev/mapper/rootvg-lv_swap
# dm-name-rootvg-lvroot /dev/mapper/rootvg-lvroot
# dm-uuid-LVM-AkjnD2jS2SCCZKbxkZeaByuZLNdHc6qCYp35NGzNbhMaL3YZYtRxuPoerlAkOcj3 /dev/mapper/rootvg-lvroot
# dm-uuid-LVM-AkjnD2jS2SCCZKbxkZeaByuZLNdHc6qCeXNhvq6sxq6LQh4aksjr1WUANFuCKooc /dev/mapper/rootvg-lv_swap
# scsi-0QEMU_QEMU_CD-ROM_drive-scsi0-0-0-0 /dev/sr0
# virtio-a1bd20bf-f66d-442c-8 /dev/vda
# virtio-a1bd20bf-f66d-442c-8-part1 /dev/vda1
# virtio-a1bd20bf-f66d-442c-8-part2 /dev/vda2
# virtio-a1bd20bf-f66d-442c-8-part3 /dev/vda3
#
# cciss-3600508b100104c3953573830524b0004 /dev/cciss/c0d0
# cciss-3600508b100104c3953573830524b0004-part1 /dev/cciss/c0d0p1

FILES="/etc/fstab /boot/grub/menu.lst /boot/grub2/grub.cfg /boot/grub/device.map /boot/efi/*/*/grub.cfg /etc/lvm/lvm.conf /etc/lilo.conf /etc/yaboot.conf /etc/default/grub_installdevice"

OLD_ID_FILE="${VAR_DIR}/recovery/diskbyid_mappings"
NEW_ID_FILE="$TMP_DIR/diskbyid_mappings"

[ ! -s "$OLD_ID_FILE" ] && return 0
[ -z "$FILES" ] && return 0

# Apply device mapping to replace device in case of migration.
# apply_layout_mappings() function defined in lib/layout-function.sh
# Inform the user when it failed to apply the layout mappings
# but do not error out here at this late state of "rear recover"
# regardless that when apply_layout_mappings failed
# some entries in OLD_ID_FILE got possibly corrupted,
# cf. https://github.com/rear/rear/issues/1845
# but hopefully the code below is sufficiently robust
# so that things work at least for those entries that are correct:
apply_layout_mappings "$OLD_ID_FILE" || LogPrintError "Failed to apply layout mappings to $OLD_ID_FILE (may cause failures during 'rename_diskbyid')"

# replace the device names with the real devices

while read ID DEV_NAME; do
    ID_NEW=""
    if [[ $DEV_NAME =~ ^dm- ]]; then
        # probably a multipath device
        # we cannot migrate device mapper targets
        # we delete DEV_NAME to make sure it won't get used
        DEV_NAME=""
    else
        # get symlinks defined by udev from a device
        # UdevSymlinkName() defined in lib/layout-function.sh
        SYMLINKS=$(UdevSymlinkName $DEV_NAME)
        set -- $SYMLINKS
        while [ $# -gt 0 ]; do
            if [[ $1 =~ /dev/disk/by-id ]]; then
                # bingo, we found what we are looking for
                ID_NEW=${1#/dev/disk/by-id/} # cciss-3600508b1001cd2b56e1aeab1f82dd70d
                break
            else
                shift
            fi
        done
    fi
    echo $ID $DEV_NAME $ID_NEW
done < "$OLD_ID_FILE" > "$NEW_ID_FILE"

sed_change_monitor="$TMP_DIR/by-id_change"

LogPrint "Migrating disk-by-id mappings in certain restored files in $TARGET_FS_ROOT to current disk-by-id mappings ..."

local file=""
local realfile=""
local symlink_target=""
for file in $FILES; do
    realfile="$TARGET_FS_ROOT/$file"
    # Silently skip directories and file not found:
    test -f "$realfile" || continue
    # 'sed -i' bails out on symlinks, so we follow the symlink and patch the symlink target
    # on dead links we inform the user and skip them
    # TODO: We should do this inside 'chroot $TARGET_FS_ROOT' so that absolute symlinks will work correctly
    # cf. https://github.com/rear/rear/issues/1338
    if test -L "$realfile" ; then
        if symlink_target="$( readlink -f "$realfile" )" ; then
            # symlink_target is an absolute path in the recovery system
            # e.g. the symlink target of etc/mtab is /mnt/local/proc/12345/mounts
            # because we use only 'pushd $TARGET_FS_ROOT' but not 'chroot $TARGET_FS_ROOT'.
            # If the symlink target does not start with /mnt/local/ (i.e. if it does not start with $TARGET_FS_ROOT)
            # it is an absolute symlink (e.g. inside $TARGET_FS_ROOT a symlink points to /absolute/path/file)
            # and the target of an absolute symlink is not within the recreated system but in the recovery system
            # where it does not make sense to patch files, cf. https://github.com/rear/rear/issues/1338
            # so that we skip patching symlink targets that are not within the recreated system:
            if ! echo $symlink_target | grep -q "^$TARGET_FS_ROOT/" ; then
                LogPrint "Skip patching symlink $realfile target $symlink_target not within $TARGET_FS_ROOT"
                continue
            fi
            # If the symlink target contains /proc/ /sys/ /dev/ or /run/ we skip it because then
            # the symlink target is considered to not be a restored file that needs to be patched
            # cf. https://github.com/rear/rear/pull/2047#issuecomment-464846777
            if echo $symlink_target | egrep -q '/proc/|/sys/|/dev/|/run/' ; then
                LogPrint "Skip patching symlink $realfile target $symlink_target on /proc/ /sys/ /dev/ or /run/"
                continue
            fi
            LogPrint "Patching symlink $realfile target $symlink_target"
            realfile="$symlink_target"
        else
            LogPrint "Skip patching dead symlink $realfile"
            continue
        fi
    fi
    # keep backup
    cp $v "$realfile" "${realfile}.rearbak"
    # we should consider creating a sed script within a string
    # and then call sed once (as done other times)
    while read ID DEV_NAME ID_NEW; do
        if [ -n "$ID_NEW" ]; then

            # If ID and ID_NEW are the same, no need to change, go the next device.
            [[ "$ID" == "$ID_NEW" ]] && continue

            # great, we found a new device
            ID_FULL=/dev/disk/by-id/$ID
            ID_NEW_FULL=/dev/disk/by-id/$ID_NEW

            # Using w flag to store changes made by sed in a output file /dev/stdout
            # then, we redirect output to $sed_change_monitor.
            # if no change is made, $sed_change_monitor will stay empty.
            sed -i "s#$ID_FULL\([^-a-zA-Z0-9]\)#$ID_NEW_FULL\1#gw /dev/stdout" "$realfile" >> "$sed_change_monitor"
            #                 ^^^^^^^^^^^^^^^
            # This is to make sure we get the full ID (and not
            # a substring) because we ask sed for a char other then
            # those contained in IDs.
            # This does not work with IDs at line end: substitute also those:

            sed -i "s#$ID_FULL\$#$ID_NEW_FULL#gw /dev/stdout" "$realfile" >> "$sed_change_monitor"
        else
            # lets try with the DEV_NAME as fallback
            [ -z "$DEV_NAME" ] && continue
            # not even DEV_NAME exists, we can't do anything
            ID_FULL=$ID
            sed -i "s#$ID_FULL\([^-a-zA-Z0-9]\)#/dev/$DEV_NAME\1#gw /dev/stdout" "$realfile" >> "$sed_change_monitor"

            sed -i "s#$ID_FULL\$#/dev/$DEV_NAME#gw /dev/null" "$realfile" >> "$sed_change_monitor"
        fi

        # Checking if sed changed something in a file (by using w sed flag)
        # LogPrint only when a change was made.
        if test -s "$sed_change_monitor" ; then
            LogPrint "Replaced '$ID_FULL' by '$ID_NEW_FULL' in $realfile"
            rm "$sed_change_monitor"
        fi

    done < $NEW_ID_FILE
done

# TODO: Use 'local' variables for that:
unset ID DEV_NAME ID_NEW SYMLINKS ID_FULL ID_NEW_FULL

