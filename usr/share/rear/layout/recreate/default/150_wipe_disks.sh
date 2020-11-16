# The disks that will be completely wiped are those disks
# where in diskrestore.sh the create_disk_label function is called
# (the create_disk_label function calls "parted -s $disk mklabel $label")
# for example like
#   create_disk_label /dev/sda gpt
#   create_disk_label /dev/sdb msdos
# so in this example DISKS_TO_BE_WIPED="/dev/sda /dev/sdb "
# cf. layout/recreate/default/120_confirm_wipedisk_disks.sh

# Log the currently existing block devices structure on the unchanged replacement hardware
# cf. how lsblk is called in layout/save/GNU/Linux/100_create_layout_file.sh
Log "Block devices structure on the unchanged replacement hardware before the disks $DISKS_TO_BE_WIPED will be wiped (lsblk):"
Log "$( lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,SIZE,MOUNTPOINT || lsblk -io NAME,KNAME,FSTYPE,SIZE,MOUNTPOINT || lsblk -i || lsblk )"

# Plain wiping a disk with LVM storage objects leads to errors later when "parted -s $disk mklabel $label" is called
# in the diskrestore.sh script because then 'parted' fails (which lets diskrestore.sh fail which lets "rear recover" fail)
# with the following error message:
#   Partitions ... have been written, but we have been unable to inform the kernel of the change,
#   probably because it/they are in use. As a result, the old partition(s) will remain in use.
#   You should probably reboot now before making further changes.
# In this case it works to reboot the recovery system and then a second "rear recover" usually succeeds
# because after plain wiping a disk with LVM storage objects the LVM metadata/signatures is no longer there
# so that LVM cannot be in use in the rebooted recovery system and "parted -s $disk mklabel $label" can succeed.
# But we like to do all in one single "rear recover" run so we need to clean up LVM storage objects properly.
# LVM storage objects must be properly detected and removed with LVM tools step by step from LVs to VGs to PVs:
local detected_LVs detected_VGs detected_PVs detected_LV detected_VG detected_PV
# Detect LVs:
# The 'lvscan' output in the recovery system looks like:
#   inactive          '/dev/system/swap' [2.00 GiB] inherit
#   inactive          '/dev/system/home' [5.39 GiB] inherit
#   inactive          '/dev/system/root' [12.59 GiB] inherit
# cf. layout/recreate/default/README.wipe_disks
detected_LVs="$( lvscan -y | cut -s -d "'" -f2 | tr -s '[:space:]' ' ' )"
# Detect VGs:
# The 'vgscan' output in the recovery system looks like:
#   Reading all physical volumes.  This may take a while...
#   Found volume group "system" using metadata type lvm2
# cf. layout/recreate/default/README.wipe_disks
detected_VGs="$( vgscan -y | grep 'Found volume group' |cut -s -d '"' -f2 | tr -s '[:space:]' ' ' )"
# Detect PVs:
# The 'pvscan' output in the recovery system looks like:
#   PV /dev/mapper/luks1sda2   VG system          lvm2 [19.98 GiB / 0    free]
#   Total: 1 [19.98 GiB] / in use: 1 [19.98 GiB] / in no VG: 0 [0   ]
# cf. layout/recreate/default/README.wipe_disks
detected_PVs="$( pvscan -y | grep -o 'PV /dev/[^ ]*' | cut -s -d ' ' -f2 | tr -s '[:space:]' ' ' )"
# Remove detected LVs ('for' does nothing when $detected_LVs is empty):
for detected_LV in $detected_LVs ; do
    if lvremove -f -y $detected_LV ; then
        DebugPrint "Removed LVM logical volume $detected_LV"
    else
        LogPrintError "Failed to remove LVM logical volume $detected_LV ('lvremove $detected_LV' failed)"
    fi
done
# Remove detected VGs ('for' does nothing when $detected_VGs is empty):
for detected_VG in $detected_VGs ; do
    if vgremove -ff -y $detected_VG ; then
        DebugPrint "Removed LVM volume group $detected_VG"
    else
        LogPrintError "Failed to remove LVM volume group $detected_VG ('vgremove $detected_VG' failed)"
    fi
done
# Remove detected PVs ('for' does nothing when $detected_PVs is empty):
for detected_PV in $detected_PVs ; do
    if pvremove -f -y $detected_PV ; then
        DebugPrint "Removed LVM physical volume $detected_PV"
    else
        LogPrintError "Failed to remove LVM physical volume $detected_PV ('pvremove $detected_PV' failed)"
    fi
done

# Wipe RAID plus LVM plus LUKS metadata.
# To wipe RAID Superblocks it is sufficient to wipe 133 KiB at the beginning and at the end of the device.
# To wipe to wipe LVM metadata is should be sufficient to wipe 4 MiB at the beginning and at the end of the device.
# To wipe LUKS headers is should be sufficient to wipe 8 MiB at the beginning of the device.
# To wipe RAID superblocks plus LVM metadata plus LUKS headers it should be sufficient to
# wipe 8 MiB + 4 MiB + 1 MiB = 13 MiB at the beginning of the device and to
# wipe 4 MiB + 1 MiB = 5 MiB at the end of the device.
# To be future proof (perhaps LUKS may add a backup header at the end of the device)
# wiping 16 MiB at the beginning and at the end of the device should be sufficiently safe.
local disk_to_be_wiped children_to_be_wiped device_to_be_wiped device_to_be_wiped_size_bytes bytes_to_be_wiped dd_seek_byte
# 16 * 1024 * 1024 = 16777216
local bytes_of_16_MiB=16777216
for disk_to_be_wiped in $DISKS_TO_BE_WIPED ; do
    # Get all child kernel devices of the disk_to_be_wiped in reverse ordering
    # so that nested children/grandchildren are first, then children and the disk_to_be_wiped last
    # which is the required ordering to wipe devices (from lowest nested up to the top level device).
    # For example when "lsblk -ipo NAME,KNAME,PKNAME,TYPE,FSTYPE,SIZE,MOUNTPOINT /dev/sda" shows
    #   NAME                                               KNAME     PKNAME    TYPE  FSTYPE       SIZE MOUNTPOINT
    #   /dev/sda                                           /dev/sda            disk                20G 
    #   |-/dev/sda1                                        /dev/sda1 /dev/sda  part                 8M 
    #   `-/dev/sda2                                        /dev/sda2 /dev/sda  part  crypto_LUKS   20G 
    #     `-/dev/mapper/cr_ata-QEMU_HARDDISK_QM00001-part2 /dev/dm-0 /dev/sda2 crypt LVM2_member   20G 
    #       |-/dev/mapper/system-swap                      /dev/dm-1 /dev/dm-0 lvm   swap           2G [SWAP]
    #       |-/dev/mapper/system-root                      /dev/dm-2 /dev/dm-0 lvm   btrfs       12.6G /
    #       `-/dev/mapper/system-home                      /dev/dm-3 /dev/dm-0 lvm   xfs          5.4G /home
    # then "lsblk -nipo KNAME /dev/sda | tac" shows
    #   /dev/dm-3
    #   /dev/dm-2
    #   /dev/dm-1
    #   /dev/dm-0
    #   /dev/sda2
    #   /dev/sda1
    #   /dev/sda
    children_to_be_wiped="$( lsblk -nipo KNAME $disk_to_be_wiped | tac | tr -s '[:space:]' ' ' )"
    # "lsblk -nipo KNAME $disk_to_be_wiped" does not work on SLES11-SP4 which is no longer supported since ReaR 2.6
    # but it works at least on SLES12-SP5 so we test that children_to_be_wiped is not empty to avoid issues on older systems:
    if ! test "$children_to_be_wiped" ; then
        LogPrintError "Skip wiping $disk_to_be_wiped (no output for 'lsblk -nipo KNAME $disk_to_be_wiped' or failed)"
        continue
    fi
    LogPrint "Wiping child devices of $disk_to_be_wiped in reverse ordering: $children_to_be_wiped"
    for device_to_be_wiped in $children_to_be_wiped ; do
        if ! test -b $device_to_be_wiped ; then
            LogPrintError "Skip wiping $device_to_be_wiped (no block device)"
            continue
        fi
        # Get the size of the device in bytes which could be smaller than 16 MiB.
        # For example a 'bios_grub' partition could be smaller (e.g only 8 MiB on SUSE systems)
        # cf. the "lsblk -ipo NAME,KNAME,PKNAME,TYPE,FSTYPE,SIZE,MOUNTPOINT /dev/sda" output above.
        device_to_be_wiped_size_bytes="$( lsblk -dbnipo SIZE $device_to_be_wiped )"
        if ! test -b $device_to_be_wiped_size_byte ; then
            LogPrintError "Skip wiping $device_to_be_wiped (no output for 'lsblk -dbnipo SIZE $device_to_be_wiped' or failed)"
            continue
        fi
        # By default wipe 16 MiB at the beginning and at the end of the device:
        bytes_to_be_wiped=$bytes_of_16_MiB
        # Wipe at most the size of the device in bytes:
        test $device_to_be_wiped_size_bytes -lt $bytes_to_be_wiped && bytes_to_be_wiped=$device_to_be_wiped_size_bytes
        # Wipe at the beginning of the device:
        if ! dd bs=1M if=/dev/zero of=$device_to_be_wiped count=$bytes_to_be_wiped conv=notrunc,fsync iflag=count_bytes ; then
            LogPrintError "Failed to wipe first $bytes_to_be_wiped bytes of $device_to_be_wiped ('dd if=/dev/zero of=$device_to_be_wiped count=$bytes_to_be_wiped iflag=count_bytes' failed)"
        else
            DebugPrint "Wiped first $bytes_to_be_wiped bytes of $device_to_be_wiped"
        fi
        # Wipe at the end of the device:
        if ! test $device_to_be_wiped_size_bytes -gt $bytes_to_be_wiped ; then
            DebugPrint "Skip wiping at the end of $device_to_be_wiped (dvice size $device_to_be_wiped_size_bytes not greater than the bytes that were wiped)"
            continue
        fi
        # The byte whereto dd should seek to wipe to the end of the device from that point:
        dd_seek_byte=$(( device_to_be_wiped_size_bytes - bytes_to_be_wiped ))
        if ! test $dd_seek_byte -gt 0 ; then
            DebugPrint "Skip wiping at the end of $device_to_be_wiped (dd seek byte would be $dd_seek_byte)"
            continue
        fi
        if ! dd bs=1M if=/dev/zero of=$device_to_be_wiped count=$bytes_to_be_wiped seek=$dd_seek_byte conv=notrunc,fsync iflag=count_bytes oflag=seek_bytes ; then
            LogPrintError "Failed to wipe last $bytes_to_be_wiped bytes of $device_to_be_wiped ('dd if=/dev/zero of=$device_to_be_wiped count=$bytes_to_be_wiped seek=$dd_seek_byte iflag=count_bytes oflag=seek_bytes' failed)"
        else
            DebugPrint "Wiped last $bytes_to_be_wiped bytes of $device_to_be_wiped"
        fi
    done
done

# Log the still existing block devices structure after the disks in DISKS_TO_BE_WIPED were wiped:
Log "Remaining block devices structure after the disks $DISKS_TO_BE_WIPED were wiped (lsblk):"
Log "$( lsblk -ipo NAME,KNAME,PKNAME,TRAN,TYPE,FSTYPE,SIZE,MOUNTPOINT || lsblk -io NAME,KNAME,FSTYPE,SIZE,MOUNTPOINT || lsblk -i || lsblk )"
