# 100_create_efiboot.sh
# USB device needs to be formatted with command 'rear format -- --efi /dev/<device_name>'
# because it sets a hardcoded label REAR-EFI in format/USB/default/300_format_usb_disk.sh
# for the VFAT EFI filesystem that is needed here.

# Do "the right thing" depending on
# whether or not there is a partition labeled 'REAR-EFI'
# and whether or not USING_UEFI_BOOTLOADER is 'true':
local efi_label="REAR-EFI"
local efi_part="/dev/disk/by-label/$efi_label"
if ! test -b "$efi_part" ; then
    if ! is_true $USING_UEFI_BOOTLOADER ; then
        # There is no partition labeled 'REAR-EFI' and USING_UEFI_BOOTLOADER is not 'true':
        DebugPrint "No EFI boot (no EFI partition '$efi_part' and USING_UEFI_BOOTLOADER is not 'true')"
        return 0
    fi
    # There is no partition labeled 'REAR-EFI' but USING_UEFI_BOOTLOADER is 'true':
    Error "USING_UEFI_BOOTLOADER is 'true' but no EFI partition '$efi_part' block device (did you prepare with 'rear format'?)"
fi
# There is a is a partition labeled 'REAR-EFI':
if ! is_true $USING_UEFI_BOOTLOADER ; then
    # There is a is a partition labeled 'REAR-EFI' and USING_UEFI_BOOTLOADER is not 'true':
    DebugPrint "Skip configuring EFI partition '$efi_part' for EFI boot (USING_UEFI_BOOTLOADER is not 'true')"
    return 0
fi
# There is a is a partition labeled 'REAR-EFI' and USING_UEFI_BOOTLOADER is 'true':
local uefi_bootloader_basename=$( basename "$UEFI_BOOTLOADER" )
DebugPrint "Configuring EFI partition '$efi_part' for EFI boot with '$uefi_bootloader_basename'"

# $BUILD_DIR is not present at this stage so TMPDIR (by default /var/tmp see default.conf) will be used instead.
# Slackware version of mktemp requires 6 Xs in template and
# plain 'mktemp' uses XXXXXXXXXX by default (at least on SLES11 and openSUSE Leap 15.0)
# so that we comply with the 'mktemp' default to avoid 'mktemp' errors "too few X's in template".
# We use local var ; var=$( COMMAND ) because local var=$( COMMAND ) || Error "COMMAND failed"
# will not error out when COMMAND failed, see https://github.com/rear/rear/wiki/Coding-Style
# and https://github.com/koalaman/shellcheck/wiki/SC2155
local efi_mpt
efi_mpt=$( mktemp -d $TMPDIR/rear-efi.XXXXXXXXXX ) || Error "mktemp failed to create mount point '$TMPDIR/rear-efi.XXXXXXXXXX' for EFI partition '$efi_part'"

local efi_dir="/EFI/BOOT"
local efi_dst="$efi_mpt/$efi_dir"

# Mount EFI partition:
mount $efi_part $efi_mpt || Error "Failed to mount EFI partition '$efi_part' at '$efi_mpt'"

# Create EFI friendly directory structure:
mkdir -p $efi_dst || Error "Failed to create directory '$efi_dst'"

# Follow symbolic links to ensure the real content gets copied
# but do not preserve mode,ownership,timestamps (i.e. no -p option) because that may fail like
# "cp: failed to preserve ownership for '/tmp/rear-efi.XXXXXXXXXX/EFI/BOOT/kernel': Operation not permitted"
# because it copies to a VFAT filesystem on the EFI partition (see format/USB/default/300_format_usb_disk.sh)
# cf. https://github.com/rear/rear/issues/2683
# Copy boot loader:
cp -L $v "$UEFI_BOOTLOADER" "$efi_dst/BOOTX64.efi" || Error "Failed to copy UEFI_BOOTLOADER '$UEFI_BOOTLOADER' to $efi_dst/BOOTX64.efi"
# Copy kernel:
cp -L $v "$KERNEL_FILE" "$efi_dst/kernel" || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE' to $efi_dst/kernel"
# Copy initrd:
cp -L $v "$TMP_DIR/$REAR_INITRD_FILENAME" "$efi_dst/$REAR_INITRD_FILENAME" || Error "Failed to copy initrd to $efi_dst/$REAR_INITRD_FILENAME"

# Configure elilo for EFI boot:
if test "$uefi_bootloader_basename" = "elilo.efi" ; then
    Log "Configuring elilo for EFI boot"
    # Create config for elilo
    DebugPrint "Creating $efi_dst/elilo.conf"
    create_ebiso_elilo_conf > $efi_dst/elilo.conf
# Configure GRUB for EFI boot:
else
    has_binary grub-install grub2-install || Error "Unknown EFI bootloader (no grub-install or grub2-install found)"
    # Choose right grub binary, cf. https://github.com/rear/rear/issues/849
    local grub_install_binary="grub-install"
    has_binary grub2-install && grub_install_binary="grub2-install"
    # Determine the GRUB version.
    # Because substr() for awk did not work as expected for this case here
    # 'cut' is used (awk '{print $NF}' prints the last column which is the version).
    # Only the first character of the version should be enough (at least for now).
    # Example output (on openSUSE Leap 15.2)
    # # grub2-install --version
    # grub2-install (GRUB2) 2.04
    # # grub2-install --version | awk '{print $NF}' | cut -c1
    # 2
    local grub_version
    grub_version=$( $grub_install_binary --version | awk '{print $NF}' | cut -c1 )
    case $grub_version in
        (0)
            DebugPrint "Configuring legacy GRUB for EFI boot"
            cat > $efi_dst/BOOTX64.conf << EOF
default=0
timeout=5
title Relax-and-Recover (no Secure Boot)
initrd $efi_dir/$REAR_INITRD_FILENAME
EOF
        ;;
        (2)
            DebugPrint "Configuring GRUB2 for EFI boot"
            # We need to set the GRUB environment variable 'root' to the partition device with label $efi_label (hardcoded "REAR-EFI")
            # because GRUB's default 'root' (or GRUB's 'root' identifcation heuristics) would point to the ramdisk but neither kernel
            # nor initrd are located on the ramdisk but on the partition device with label $efi_label.
            # GRUB2_SET_ROOT_COMMAND and/or GRUB2_SEARCH_ROOT_COMMAND is needed by the create_grub2_cfg() function.
            # Set GRUB2_SEARCH_ROOT_COMMAND if not specified by the user:
            contains_visible_char "$GRUB2_SEARCH_ROOT_COMMAND" || GRUB2_SEARCH_ROOT_COMMAND="search --no-floppy --set=root --label $efi_label"
            # Create config for GRUB2:
            create_grub2_cfg $efi_dir/kernel $efi_dir/$REAR_INITRD_FILENAME > $efi_dst/grub.cfg
            # Create bootloader, this overwrites BOOTX64.efi copied in previous step:
            build_bootx86_efi $efi_dst/BOOTX64.efi $efi_dst/grub.cfg "/boot" "$UEFI_BOOTLOADER"
        ;;
        (*)
            Error "GRUB version '$grub_version' is neither '0' (legacy GRUB) nor '2' (GRUB 2)"
        ;;
    esac
fi

# Cleanup of EFI temporary mount point:
if umount $efi_mpt ; then
    rmdir $efi_mpt || LogPrintError "Could not remove temporary directory '$efi_mpt' (you should do it manually)"
else
    LogPrintError "Could not umount EFI partition '$efi_part' at '$efi_mpt' (you should do it manually)"
fi
