# 250_populate_efibootimg.sh

is_true $USING_UEFI_BOOTLOADER || return 0 # empty or 0 means NO UEFI

mkdir $v -p $TMP_DIR/mnt/EFI/BOOT >&2
StopIfError "Could not create $TMP_DIR/mnt/EFI/BOOT"

mkdir $v -p $TMP_DIR/mnt/EFI/BOOT/fonts >&2
StopIfError "Could not create $TMP_DIR/mnt/EFI/BOOT/fonts"

mkdir $v -p $TMP_DIR/mnt/EFI/BOOT/locale >&2
StopIfError "Could not create $TMP_DIR/mnt/EFI/BOOT/locale"

# copy the grub*.efi executable to EFI/BOOT/BOOTX64.efi
cp  $v "${UEFI_BOOTLOADER}" $TMP_DIR/mnt/EFI/BOOT/BOOTX64.efi >&2
StopIfError "Could not find ${UEFI_BOOTLOADER}"
if test -f "$SECURE_BOOT_BOOTLOADER" ; then
    # if shim is used, bootloader can be actually anything
    # named as grub*.efi (follow-up loader is shim compile time option)
    # http://www.rodsbooks.com/efi-bootloaders/secureboot.html#initial_shim
    cp $v $(dirname ${UEFI_BOOTLOADER})/grub*.efi $TMP_DIR/mnt/EFI/BOOT/ >&2
fi


# FIXME: do we need to test if we are ebiso at all?
# copying kernel should happen for any ueafi mkiso tool with elilo
if [[ $(basename $ISO_MKISOFS_BIN) = "ebiso" ]]; then
    # See https://github.com/rear/rear/issues/758 why 'test' is used here:
    uefi_bootloader_basename=$( basename "$UEFI_BOOTLOADER" )
    if test -f "$SECURE_BOOT_BOOTLOADER" -o "$uefi_bootloader_basename" = "elilo.efi" ; then
        # if shim is used, bootloader can be actually anything (also elilo)
        # named as grub*.efi (follow-up loader is shim compile time option)
        # http://www.rodsbooks.com/efi-bootloaders/secureboot.html#initial_shim
        # if shim is used, bootloader can be actually also elilo
        # elilo is not smart enough to look for them outside ...
        Log "Copying kernel"

        # copy initrd and kernel inside efi_boot image as
        cp -pL $v $KERNEL_FILE $TMP_DIR/mnt/EFI/BOOT/kernel >&2
        StopIfError "Could not copy kernel to UEFI"
        cp $v $TMP_DIR/$REAR_INITRD_FILENAME $TMP_DIR/mnt/EFI/BOOT/$REAR_INITRD_FILENAME >&2
        StopIfError "Could not copy $REAR_INITRD_FILENAME to UEFI"
        create_ebiso_elilo_conf > $TMP_DIR/mnt/EFI/BOOT/elilo.conf
        create_grub2_cfg > $TMP_DIR/mnt/EFI/BOOT/grub.cfg
    fi
fi

if [[ -n "$(type -p grub)" ]]; then
cat > $TMP_DIR/mnt/EFI/BOOT/BOOTX64.conf << EOF
default=0
timeout 5
splashimage=/EFI/BOOT/splash.xpm.gz
title Relax-and-Recover (no Secure Boot)
    kernel /isolinux/kernel $KERNEL_CMDLINE
    initrd /isolinux/$REAR_INITRD_FILENAME

EOF
else
# create small embedded grub.cfg file for grub-mkimage
cat > $TMP_DIR/mnt/EFI/BOOT/embedded_grub.cfg <<EOF
set prefix=(cd0)/EFI/BOOT
configfile /EFI/BOOT/grub.cfg
EOF

# create a grub.cfg
    create_grub2_cfg > $TMP_DIR/mnt/EFI/BOOT/grub.cfg
fi

# Create BOOTX86.efi but only if we are NOT secure booting.
# We are not able to create signed boot loader
# so we need to reuse existing one.
# See issue #1374
# build_bootx86_efi () can be safely used for other scenarios.
if ! test -f "$SECURE_BOOT_BOOTLOADER" ; then
    build_bootx86_efi
fi

# We will be using grub-efi or grub2 (with efi capabilities) to boot from ISO.
# Because usr/sbin/rear sets 'shopt -s nullglob' the 'echo -n' command
# outputs nothing if nothing matches the bash globbing pattern '/boot/grub*'
local grubdir="$( echo -n /boot/grub* )"
# Use '/boot/grub' as fallback if nothing matches '/boot/grub*'
test -d "$grubdir" || grubdir='/boot/grub'

if [ -d $(dirname ${UEFI_BOOTLOADER})/fonts ]; then
    cp $v $(dirname ${UEFI_BOOTLOADER})/fonts/* $TMP_DIR/mnt/EFI/BOOT/fonts/ >&2
    StopIfError "Could not copy $(dirname ${UEFI_BOOTLOADER})/fonts/ files"
elif [ -d $grubdir/fonts ]; then
    cp $v $grubdir/fonts/* $TMP_DIR/mnt/EFI/BOOT/fonts/ >&2
    StopIfError "Could not copy $grubdir/fonts/ files"
else
    Log "Warning: did not find $grubdir/fonts directory (UEFI ISO boot in danger)"
fi

if [ -d $grubdir/locale ]; then
    cp $v $grubdir/locale/* $TMP_DIR/mnt/EFI/BOOT/locale/ >&2
    StopIfError "Could not copy $grubdir/locale/ files"
else
    Log "Warning: did not find $grubdir/locale directory (minor issue)"
fi

# copy of efiboot content also the our ISO tree (isofs/)
mkdir $v -p -m 755 $TMP_DIR/isofs/EFI/BOOT >&2
cp $v -r $TMP_DIR/mnt/EFI  $TMP_DIR/isofs/ >&2
StopIfError "Could not create the isofs/EFI/BOOT directory on the ISO image"

# make /boot/grub/grub.cfg available on isofs/
mkdir $v -p -m 755 $TMP_DIR/isofs/boot/grub >&2
if [[ -n "$(type -p grub)" ]]; then
    cp $v $TMP_DIR/isofs/EFI/BOOT/BOOTX64.conf  $TMP_DIR/isofs/boot/grub/ >&2
else
    cp $v $TMP_DIR/isofs/EFI/BOOT/grub.cfg  $TMP_DIR/isofs/boot/grub/ >&2
fi

StopIfError "Could not copy grub config file to isofs/boot/grub"

ISO_FILES=( "${ISO_FILES[@]}" )
