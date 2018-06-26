#
# This  script is an improvement over a blind "grub-install (hd0)".
#
# However the following issues still exist:
#
# * We don't know what the first disk will be, so we cannot be sure the MBR
#   is written to the correct disk. That's why we make all disks bootable
#   as fallback unless GRUB2_INSTALL_DEVICE was specified.
#
# * There is no guarantee that GRUB2 was the boot loader used originally.
#   One solution is to save and restore the MBR for each disk, but this
#   does not guarantee a correct boot-order, or even a working bootloader config.

# Skip if another bootloader was already installed:
# In this case NOBOOTLOADER is not true,
# cf. finalize/default/050_prepare_checks.sh
is_true $NOBOOTLOADER || return 0

# For UEFI systems with grub2 we should use efibootmgr instead,
# cf. finalize/Linux-i386/630_run_efibootmgr.sh
is_true $USING_UEFI_BOOTLOADER && return 

# Only for GRUB2 - GRUB Legacy will be handled by its own script.
# GRUB2 is detected by testing for grub-probe or grub2-probe which does not exist in GRUB Legacy.
# If neither grub-probe nor grub2-probe is there assume GRUB2 is not there:
type -p grub-probe || type -p grub2-probe || return 0

LogPrint "Installing GRUB2 boot loader..."

# Make /proc /sys /dev available in TARGET_FS_ROOT
# so that later things work in the "chroot TARGET_FS_ROOT" environment,
# cf. https://github.com/rear/rear/issues/1828#issuecomment-398717889
# and do not umount them because it is better when also after "rear recover"
# things still work in the "chroot TARGET_FS_ROOT" environment
# so that the user could more easily adapt things after "rear recover":
for mount_device in proc sys dev ; do
    umount $TARGET_FS_ROOT/$mount_device && sleep 1
    mount --bind /$mount_device $TARGET_FS_ROOT/$mount_device
done

# Check if we find GRUB2 where we expect it (GRUB2 can be in boot/grub or boot/grub2):
grub_name="grub2"
if ! test -d "$TARGET_FS_ROOT/boot/$grub_name" ; then
    grub_name="grub"
    if ! test -d "$TARGET_FS_ROOT/boot/$grub_name" ; then
        LogPrintError "Cannot install GRUB2 (neither boot/grub nor boot/grub2 directory in $TARGET_FS_ROOT)"
        return 1
    fi
fi

# Generate GRUB configuration file anew to be on the safe side (this could be even mandatory in MIGRATION_MODE):
if ! chroot $TARGET_FS_ROOT /bin/bash --login -c "$grub_name-mkconfig -o /boot/$grub_name/grub.cfg" ; then
    LogPrintError "Failed to generate boot/$grub_name/grub.cfg in $TARGET_FS_ROOT - trying to install GRUB2 nevertheless"
fi

# When GRUB2_INSTALL_DEVICE is explicitly specified by the user install GRUB2 there:
if test "$GRUB2_INSTALL_DEVICE" ; then
    LogPrint "Installing GRUB2 on $GRUB2_INSTALL_DEVICE (specified as GRUB2_INSTALL_DEVICE)"
    if chroot $TARGET_FS_ROOT /bin/bash --login -c "$grub_name-install $GRUB2_INSTALL_DEVICE" ; then
        NOBOOTLOADER=''
        return
    fi
    LogPrintError "Failed to install GRUB2 on the specified $GRUB2_INSTALL_DEVICE"
fi

# If GRUB2_INSTALL_DEVICE is not specified or it failed to install GRUB2 there
# try to automatically determine where to install GRUB2:
if ! test -r "$LAYOUT_FILE" -a -r "$LAYOUT_DEPS" ; then
    LogPrintError "Cannot determine where to install GRUB2"
    return 1
fi
test "$GRUB2_INSTALL_DEVICE" && LogPrint "Determining where to install GRUB2" || LogPrint "Determining where to install GRUB2 (no GRUB2_INSTALL_DEVICE specified)"

# Find exclusive partition(s) belonging to /boot or / (if /boot is inside root filesystem):
if test "$( filesystem_name $TARGET_FS_ROOT/boot )" = "$TARGET_FS_ROOT" ; then
    bootparts=$( find_partition fs:/ )
else
    bootparts=$( find_partition fs:/boot )
fi
if ! test "$bootparts" ; then
    LogPrintError "Cannot install GRUB2 (unable to find a /boot or / partition)"
    return 1
fi

# Find the disks that need a new GRUB2 MBR:
disks=$( grep '^disk \|^multipath ' $LAYOUT_FILE | cut -d' ' -f2 )
if ! test "$disks" ; then
    LogPrintError "Cannot install GRUB2 (unable to find a disk)"
    return 1
fi

for disk in $disks ; do
    # Installing GRUB2 on an LVM PV will wipe the metadata so we skip those:
    is_disk_a_pv "$disk" && continue

    # Use first boot partition by default:
    part=$( echo $bootparts | cut -d' ' -f1 )

    # Use boot partition that matches this disk, if any:
    for bootpart in $bootparts ; do
        bootdisk=$( find_disk_and_multipath "$bootpart" )
        if test "$disk" = "$bootdisk" ; then
            part=$bootpart
            break
        fi
    done

    # Find boot disk and partition number:
    bootdisk=$( find_disk_and_multipath "$part" )

    # Install GRUB2 on the boot disk if one was found:
    if test "$bootdisk" ; then
        LogPrint "Found possible boot disk $bootdisk - installing GRUB2 there"
        if chroot $TARGET_FS_ROOT /bin/bash --login -c "$grub_name-install $bootdisk" ; then
            NOBOOTLOADER=''
            # We don't know what the first disk will be, so we cannot be sure the MBR
            # is written to the correct disk. That's why we make all disks bootable:
            continue
        fi
        LogPrintError "Failed to install GRUB2 on $bootdisk"
    fi
done

is_true $NOBOOTLOADER && LogPrintError "Failed to install GRUB2 - you may have to manually install it"
return 1

