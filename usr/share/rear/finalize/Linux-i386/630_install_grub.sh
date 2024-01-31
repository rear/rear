# This script is an improvement over the default grub-install '(hd0)'
#
# However the following issues still exist:
#
#  * We don't know what the first disk will be, so we cannot be sure the MBR
#    is written to the correct disk(s). That's why we make all disks bootable.
#
#  * There is no guarantee that GRUB was the boot loader used originally.
#    One possible attempt would be to save and restore the MBR for each disk,
#    but this does not guarantee a correct boot order,
#    or even a working boot loader config
#    (eg. GRUB stage2 might not be at the exact same location).

# Skip if another boot loader is already installed
# (then $NOBOOTLOADER is not a true value cf. finalize/default/010_prepare_checks.sh):
is_true $NOBOOTLOADER || return 0

# For UEFI systems with grub legacy with should use efibootmgr instead,
# but if BOOTLOADER is explicitly set to GRUB, we are on a hybrid (BIOS/UEFI)
# boot system and we need to install GRUB to MBR as well.
# Therefore, we don't test $USING_UEFI_BOOTLOADER.

# If the BOOTLOADER variable (read by finalize/default/010_prepare_checks.sh)
# is not "GRUB" (which means GRUB Legacy) skip this script (which is only for GRUB Legacy)
# because finalize/Linux-i386/660_install_grub2.sh is for installing GRUB 2
# and finalize/Linux-i386/650_install_elilo.sh is for installing elilo:
test "GRUB" = "$BOOTLOADER" || return 0

# If the BOOTLOADER variable is "GRUB" (which means GRUB Legacy)
# we could in principle trust that and continue because
# layout/save/default/445_guess_bootloader.sh (where the value has been set)
# is now able to distinguish between GRUB Legacy and GRUB 2.
# But, as this code used to support the value "GRUB" for GRUB 2,
# the user can have BOOTLOADER=GRUB set explicitly in the configuration file
# and then it overrides the autodetection in layout/save/default/445_guess_bootloader.sh .
# The user expects this setting to work with GRUB 2, thus for backward compatibility
# we need to take into accout the possibility that GRUB actually means GRUB 2.
if is_grub2_installed ; then
    LogPrint "Skip installing GRUB Legacy boot loader because GRUB 2 is installed."
    # We have the ErrorIfDeprecated function, but it aborts ReaR by default,
    # which is not a good thing to do during recovery.
    # Therefore it better to log a warning and continue.
    LogPrintError "WARNING: setting BOOTLOADER=GRUB for GRUB 2 is deprecated, set BOOTLOADER=GRUB2 if setting BOOTLOADER explicitly"
    return
fi

# The actual work:
LogPrint "Installing GRUB Legacy boot loader:"
# See above for the reasoning why not to use ErrorIfDeprecated
LogPrintError "WARNING: support for GRUB Legacy is deprecated"

# Installing GRUB Legacy boot loader requires an executable "grub":
type -p grub >&2 || Error "Cannot install GRUB Legacy boot loader because there is no 'grub' program."

if [[ -r "$LAYOUT_FILE" && -r "$LAYOUT_DEPS" ]] ; then

    # Check if we find GRUB stage 2 where we expect it
    test -d "$TARGET_FS_ROOT/boot" || Error "Could not find directory $TARGET_FS_ROOT/boot"
    test -d "$TARGET_FS_ROOT/boot/grub" || Error "Could not find directory $TARGET_FS_ROOT/boot/grub"
    test -r "$TARGET_FS_ROOT/boot/grub/stage2" || Error "Unable to find $TARGET_FS_ROOT/boot/grub/stage2"

    # Find exclusive partition(s) belonging to /boot
    # or / (if /boot is inside root filesystem)
    if test "$TARGET_FS_ROOT" = "$( filesystem_name $TARGET_FS_ROOT/boot )" ; then
        bootparts=$( find_partition fs:/ )
        grub_prefix=/boot/grub
    else
        bootparts=$( find_partition fs:/boot )
        grub_prefix=/grub
    fi
    # Should never happen
    test "$bootparts" || BugError "Unable to find any /boot partitions."

    # Find the disks that need a new GRUB MBR
    disks=$( grep '^disk \|^multipath ' $LAYOUT_FILE | cut -d' ' -f2 )
    test "$disks" || Error "Unable to find any disks."

    for disk in $disks ; do
        # Installing grub on an LVM PV will wipe the metadata so we skip those
        # function is_disk_a_pv returns true if disk is a PV
        is_disk_a_pv "$disk"  &&  continue
        # Is the disk suitable for GRUB installation at all?
        is_disk_grub_candidate "$disk" || continue
        # Use first boot partition by default
        part=$( echo $bootparts | cut -d' ' -f1 )

        # Use boot partition that matches with this disk, if any
        for bootpart in $bootparts ; do
            bootdisk=$( find_disk_and_multipath "$bootpart" )
            if test "$bootdisk" = "$disk" ; then
                part=$bootpart
                break
            fi
        done

        # Find boot-disk and partition number
        bootdisk=$( find_disk_and_multipath "$part" )
        partnr=${part#$bootdisk}
        partnr=${partnr#p}
        partnr=$(( partnr - 1 ))

        if test "$bootdisk" = "$disk" ; then
            # Best case scenario is to have /boot on disk with MBR booted
            if chroot $TARGET_FS_ROOT grub --batch --no-floppy >&2 <<EOF
device (hd0) $disk
root (hd0,$partnr)
setup --stage2=/boot/grub/stage2 --prefix=$grub_prefix (hd0)
quit
EOF
            then NOBOOTLOADER=""
                 LogPrint "Installed GRUB Legacy boot loader with /boot on disk with MBR booted on 'device (hd0) $disk' with 'root (hd0,$partnr)'."
            fi
        else
            # hd1 is a best effort guess, we cannot predict how numbering
            # changes when a disk fails.
            if chroot $TARGET_FS_ROOT grub --batch --no-floppy >&2 <<EOF
device (hd0) $disk
device (hd1) $bootdisk
root (hd1,$partnr)
setup --stage2=/boot/grub/stage2 --prefix=$grub_prefix (hd0)
quit
EOF
            then NOBOOTLOADER=""
                 LogPrint "Installed GRUB Legacy boot loader on hd1 as best effort guess on 'device (hd0) $disk' and 'device (hd1) $bootdisk' with 'root (hd1,$partnr)'."
            fi
        fi

    done
fi

if test "$NOBOOTLOADER" ; then
    if chroot $TARGET_FS_ROOT grub-install '(hd0)' >&2 ; then
        NOBOOTLOADER=""
        LogPrint "Installed GRUB Legacy boot loader via 'grub-install (hd0)'."
    fi
fi

# This script is meant to get the GRUB Legacy boot loader installed:
is_true $NOBOOTLOADER && Error "Failed to install GRUB Legacy boot loader."

