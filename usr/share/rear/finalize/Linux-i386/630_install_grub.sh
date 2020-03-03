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

# For UEFI systems with grub legacy with should use efibootmgr instead:
is_true $USING_UEFI_BOOTLOADER && return

# If the BOOTLOADER variable (read by finalize/default/010_prepare_checks.sh)
# is not "GRUB" (which means GRUB Legacy) skip this script (which is only for GRUB Legacy)
# because finalize/Linux-i386/660_install_grub2.sh is for installing GRUB 2
# and finalize/Linux-i386/650_install_elilo.sh is for installing elilo:
test "GRUB" = "$BOOTLOADER" || return 0

# If the BOOTLOADER variable is "GRUB" (which means GRUB Legacy)
# do not unconditionally trust that because https://github.com/rear/rear/pull/589
# reads (excerpt):
#   Problems found:
#   The ..._install_grub.sh checked for GRUB2 which is not part
#   of the first 2048 bytes of a disk - only GRUB was present -
#   thus the check for grub-probe/grub2-probe
# and https://github.com/rear/rear/commit/079de45b3ad8edcf0e3df54ded53fe955abded3b
# reads (excerpt):
#    replace grub-install by grub-probe
#    as grub-install also exist in legacy grub
# so that it seems there are cases where actually GRUB 2 is used
# but wrongly detected as "GRUB" so that another test is needed
# to detected if actually GRUB 2 is used and that test is to
# check if grub-probe or grub2-probe is installed because
# grub-probe or grub2-probe is only installed in case of GRUB 2
# and when GRUB 2 is installed we assume GRUB 2 is used as boot loader
# so that then we skip this script (which is only for GRUB Legacy)
# because finalize/Linux-i386/660_install_grub2.sh is for installing GRUB 2:
if type -p grub-probe >&2 || type -p grub2-probe >&2 ; then
    LogPrint "Skip installing GRUB Legacy boot loader because GRUB 2 is installed (grub-probe or grub2-probe exist)."
    return
fi

# The actual work:
LogPrint "Installing GRUB Legacy boot loader:"

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
        # function is_disk_a_pv returns with 1 if disk is a PV
        is_disk_a_pv "$disk"  ||  continue
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

