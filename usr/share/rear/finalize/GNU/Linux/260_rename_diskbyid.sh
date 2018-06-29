# remove existing disk-by-id mappings
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
apply_layout_mappings "$OLD_ID_FILE" ||  LogPrintError "Failed to apply layout mappings to $OLD_ID_FILE (may cause failures during 'rename_diskbyid')"

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

for file in $FILES; do
    realfile="$TARGET_FS_ROOT/$file"
    [ ! -f "$realfile" ] && continue	# if file is not there continue with next one
    # keep backup
    cp "$realfile" "${realfile}.rearbak"
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

        # Checking if sed change something in a file (by using w sed flag)
        # LogPrint only when a change was made.
        if test -s "$sed_change_monitor" ; then
            LogPrint "Patching $file: Replacing [$ID_FULL] by [$ID_NEW_FULL]"
            rm "$sed_change_monitor"
        fi

    done < $NEW_ID_FILE
done

unset ID DEV_NAME ID_NEW SYMLINKS ID_FULL ID_NEW_FULL

