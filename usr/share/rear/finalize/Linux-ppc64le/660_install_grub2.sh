#
# This script is an improvement over a blind "grub-install (hd0)".
#
##############################################################################
# This script is based on finalize/Linux-i386/620_install_grub2.sh
# but this script contains PPC64/PPC64LE specific code.
##############################################################################
#
# The generic way how to install GRUB2 when one is not "inside" the system
# but "outside" like in the ReaR recovery system or in a rescue system is
# to install GRUB2 from within the target system environment via 'chroot'
# basically via commands like the following:
#
#   mount --bind /proc /mnt/local/proc
#   mount --bind /sys /mnt/local/sys
#   mount --bind /dev /mnt/local/dev
#   chroot /mnt/local /usr/sbin/grub2-mkconfig -o /boot/grub2/grub.cfg
#   chroot /mnt/local /usr/sbin/grub2-install /dev/sda
#
# Using 'grub2-install --root-directory' instead of 'chroot' is not a good idea,
# see https://github.com/rear/rear/issues/1828#issuecomment-398717889
#
# The procedure is the same when GRUB2 is used on POWER architecture
# e.g. on PPC64 or PPC64LE but there the GRUB2 install device
# has to be a PPC PReP boot partition.
# On POWER architecture the Open Firmware is configured
# to read the ELF image embedded in the PReP boot partition
# (like how the MBR is used by PC x86 BIOS to embed boot code).
#
# However the following issues still exist:
#
# * We do not know what the first boot device will be, so we cannot be sure
#   GRUB2 is installed on the correct boot device.
#   If software RAID1 is used, several boot devices will be found and
#   then GRUB2 needs to be installed on each of them because
#   "You don't want to lose the first disk and suddenly discover your system won't reboot!"
#   cf. https://raid.wiki.kernel.org/index.php/Setting_up_a_(new)_system
#   This is the reason why we make all possible boot disks bootable
#   as fallback unless GRUB2_INSTALL_DEVICES was specified.
#   This is also the reason why more than one disk can be specified
#   in GRUB2_INSTALL_DEVICES.
#
# * There is no guarantee that GRUB2 was used as bootloader on the original system.
#   The solution is to specify the BOOTLOADER config variable.
#
# This script does not error out because at this late state of "rear recover"
# (i.e. after the backup was restored) I <jsmeix@suse.de> consider it too hard
# to abort "rear recover" when it failed to install GRUB2 because in this case
# the user gets an explicit WARNING via finalize/default/890_finish_checks.sh
# so that after "rear recover" finished he can manually install the bootloader
# as appropriate for his particular system.

# Skip if another bootloader was already installed:
# In this case NOBOOTLOADER is not true,
# cf. finalize/default/050_prepare_checks.sh
is_true $NOBOOTLOADER || return 0

# For UEFI systems with grub2 we should use efibootmgr instead,
# cf. finalize/Linux-i386/630_run_efibootmgr.sh
# Perhaps this does not apply on PPC64/PPC64LE because
# probably there is no UEFI on usual PPC64/PPC64LE systems
# but https://github.com/andreiw/ppc64le-edk2 reads (excerpts):
#   "TianoCore on PowerPC 64 Little-Endian (OPAL/PowerNV)
#    This is 'UEFI' on top of OPAL firmware"
# so that there could be UEFI via OPAL firmware on PPC64LE systems
# which is the reason to keep this test here also for PPC64/PPC64LE
# (if UEFI is not used the test condition will not become true):
is_true $USING_UEFI_BOOTLOADER && return

# Only for GRUB2 - GRUB Legacy will be handled by its own script.
# GRUB2 is detected by testing for grub-probe or grub2-probe which does not exist in GRUB Legacy.
# If neither grub-probe nor grub2-probe is there assume GRUB2 is not there:
type -p grub-probe || type -p grub2-probe || return 0

LogPrint "Installing GRUB2 boot loader on PPC64/PPC64LE..."

# Check if we find GRUB2 where we expect it (GRUB2 can be in boot/grub or boot/grub2):
grub_name="grub2"
if ! test -d "$TARGET_FS_ROOT/boot/$grub_name" ; then
    grub_name="grub"
    if ! test -d "$TARGET_FS_ROOT/boot/$grub_name" ; then
        LogPrintError "Cannot install GRUB2 (neither boot/grub nor boot/grub2 directory in $TARGET_FS_ROOT)"
        return 1
    fi
fi

# Make /proc /sys /dev available in TARGET_FS_ROOT
# so that later things work in the "chroot TARGET_FS_ROOT" environment,
# cf. https://github.com/rear/rear/issues/1828#issuecomment-398717889
# and do not umount them when leaving this script because
# it is better when also after "rear recover" things still
# work in the "chroot TARGET_FS_ROOT" environment so that
# the user could more easily adapt things after "rear recover":
for mount_device in proc sys dev ; do
    umount $TARGET_FS_ROOT/$mount_device && sleep 1
    mount --bind /$mount_device $TARGET_FS_ROOT/$mount_device
done

# Generate GRUB configuration file anew to be on the safe side (this could be even mandatory in MIGRATION_MODE):
if ! chroot $TARGET_FS_ROOT /bin/bash --login -c "$grub_name-mkconfig -o /boot/$grub_name/grub.cfg" ; then
    LogPrintError "Failed to generate boot/$grub_name/grub.cfg in $TARGET_FS_ROOT - trying to install GRUB2 nevertheless"
fi

# Do not update nvram when system is running in PowerNV mode (BareMetal).
# grub2-install will fail if not run with the --no-nvram option on a PowerNV system,
# see https://github.com/rear/rear/pull/1742
grub2_install_option=""
if [[ $(awk '/platform/ {print $NF}' < /proc/cpuinfo) == PowerNV ]] ; then
    grub2_install_option="--no-nvram"
fi

# When GRUB2_INSTALL_DEVICES is specified by the user
# install GRUB2 only there and nowhere else:
if test "$GRUB2_INSTALL_DEVICES" ; then
    grub2_install_failed="no"
    for grub2_install_device in $GRUB2_INSTALL_DEVICES ; do
        # In MIGRATION_MODE disk mappings (in var/lib/rear/layout/disk_mappings)
        # are applied when devices in GRUB2_INSTALL_DEVICES match
        # cf. https://github.com/rear/rear/issues/1437
        # MAPPING_FILE (var/lib/rear/layout/disk_mappings)
        # is set in layout/prepare/default/300_map_disks.sh
        # only if MIGRATION_MODE is true:
        if test -s "$MAPPING_FILE" ; then
            # Cf. the function apply_layout_mappings() in lib/layout-functions.sh
            while read source_disk target_disk junk ; do
                # Skip lines that have wrong syntax:
                test "$source_disk" -a "$target_disk" || continue
                if test "$grub2_install_device" = "$source_disk" ; then
                    LogPrint "Installing GRUB2 on $target_disk ($source_disk in GRUB2_INSTALL_DEVICES is mapped to $target_disk in $MAPPING_FILE)"
                    grub2_install_device="$target_disk"
                    break
                fi
            done < <( grep -v '^#' "$MAPPING_FILE" )
        else
            LogPrint "Installing GRUB2 on $grub2_install_device (specified in GRUB2_INSTALL_DEVICES)"
        fi
        if ! chroot $TARGET_FS_ROOT /bin/bash --login -c "$grub_name-install $grub2_install_option $grub2_install_device" ; then
            LogPrintError "Failed to install GRUB2 on $grub2_install_device"
            grub2_install_failed="yes"
        fi
    done
    is_false $grub2_install_failed && NOBOOTLOADER=''
    # return even if it failed to install GRUB2 on one of the specified GRUB2_INSTALL_DEVICES
    # because then the user gets an explicit WARNING via finalize/default/890_finish_checks.sh
    is_true $NOBOOTLOADER && return 1 || return 0
fi

# If GRUB2_INSTALL_DEVICES is not specified try to automatically determine where to install GRUB2:
if ! test -r "$LAYOUT_FILE" ; then
    LogPrintError "Cannot determine where to install GRUB2"
    return 1
fi
LogPrint "Determining where to install GRUB2 (no GRUB2_INSTALL_DEVICES specified)"

# Find PPC PReP Boot partitions:
part_list=$( awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $LAYOUT_FILE )
if ! test "$part_list" ; then
    LogPrintError "Cannot install GRUB2 (unable to find a PPC PReP boot partition)"
    return 1
fi

# We do not know what the first boot device will be, so we cannot be sure
# GRUB2 is installed on the correct boot device.
# If software RAID1 is used, several boot devices will be found and
# then GRUB2 needs to be installed on each of them.
# This is the reason why we make all possible boot disks bootable here:
for part in $part_list ; do
    # Install GRUB2 on the PPC PReP boot partition if one was found:
    if test "$part" ; then
        LogPrint "Found PPC PReP boot partition $part - installing GRUB2 there"
        # Erase the first 512 bytes of the PPC PReP boot partition:
        dd if=/dev/zero of=$part
        if chroot $TARGET_FS_ROOT /bin/bash --login -c "$grub_name-install $grub2_install_option $part" ; then
            # In contrast to the above behaviour when GRUB2_INSTALL_DEVICES is specified
            # consider it here as a successful bootloader installation when GRUB2
            # got installed on at least one PPC PReP boot partition:
            NOBOOTLOADER=''
            # Continue with the next PPC PReP boot partition:
            continue
        fi
        LogPrintError "Failed to install GRUB2 on PPC PReP boot partition $part"
    fi
done

is_true $NOBOOTLOADER || return 0
LogPrintError "Failed to install GRUB2 - you may have to manually install it"
return 1

