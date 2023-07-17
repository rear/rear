# 250_populate_efibootimg.sh

# Skip if no UEFI is used:
is_true $USING_UEFI_BOOTLOADER || return 0

# Use 260_populate_efistub.sh instead.
# There much of Grub/Elilo code here exclude it in menaningfull way.
is_true $EFI_STUB && return 0

local boot_dir="/boot"
local efi_boot_tmp_dir="$TMP_DIR/mnt/EFI/BOOT"
mkdir $v -p $efi_boot_tmp_dir || Error "Could not create $efi_boot_tmp_dir"
mkdir $v -p $efi_boot_tmp_dir/fonts || Error "Could not create $efi_boot_tmp_dir/fonts"
mkdir $v -p $efi_boot_tmp_dir/locale || Error "Could not create $efi_boot_tmp_dir/locale"

# Copy the grub*.efi or shim.efi executable to EFI/BOOT/BOOTX64.efi
# Intentionally an empty UEFI_BOOTLOADER results an invalid "cp -v /tmp/.../mnt/EFI/BOOT/BOOTX64.efi" command that fails:
cp $v "$UEFI_BOOTLOADER" $efi_boot_tmp_dir/BOOTX64.efi || Error "Could not find UEFI_BOOTLOADER '$UEFI_BOOTLOADER'"
local uefi_bootloader_dirname="$( dirname $UEFI_BOOTLOADER )"
if test -f "$SECURE_BOOT_BOOTLOADER" ; then
    # For a technical description of Shim see https://mjg59.dreamwidth.org/19448.html
    # Shim is a signed EFI binary that is a first stage bootloader
    # that loads and executes another (signed) EFI binary
    # which normally is a second stage bootloader
    # which normally is a GRUB EFI binary
    # which normally is available as a file named grub*.efi
    # so when SECURE_BOOT_BOOTLOADER is used as UEFI_BOOTLOADER
    # (cf. rescue/default/850_save_sysfs_uefi_vars.sh)
    # then Shim (usually shim.efi) was copied above as efi_boot_tmp_dir/BOOTX64.efi
    # and Shim's second stage bootloader must be also copied where Shim already is.
    DebugPrint "Using Shim '$SECURE_BOOT_BOOTLOADER' as first stage UEFI bootloader BOOTX64.efi"
    # When Shim is used, its second stage bootloader can be actually anything
    # named grub*.efi (second stage bootloader is Shim compile time option), see
    # http://www.rodsbooks.com/efi-bootloaders/secureboot.html#initial_shim
    local second_stage_UEFI_bootloader_files="$( echo $uefi_bootloader_dirname/grub*.efi )"
    # Avoid 'nullglob' pitfall when nothing matches .../grub*.efi which results
    # an invalid "cp -v /tmp/.../mnt/EFI/BOOT/" command that fails
    # cf. https://github.com/rear/rear/issues/1921
    test "$second_stage_UEFI_bootloader_files" || Error "Could not find second stage bootloader '$uefi_bootloader_dirname/grub*.efi' for Shim"
    DebugPrint "Using second stage UEFI bootloader files for Shim: $second_stage_UEFI_bootloader_files"
    cp $v $second_stage_UEFI_bootloader_files $efi_boot_tmp_dir/ || Error "Failed to copy second stage bootloader files for Shim"
fi

# FIXME: Do we need to test if we are ebiso at all?
#        Copying kernel should happen for any uefi mkiso tool with elilo.
if test "ebiso" = "$( basename $ISO_MKISOFS_BIN )" ; then
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
        cp -pL $v $KERNEL_FILE $efi_boot_tmp_dir/kernel || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE' to $efi_boot_tmp_dir/kernel"
        cp $v $TMP_DIR/$REAR_INITRD_FILENAME $efi_boot_tmp_dir/$REAR_INITRD_FILENAME || Error "Failed to copy initrd '$REAR_INITRD_FILENAME' into $efi_boot_tmp_dir"
        create_ebiso_elilo_conf > $efi_boot_tmp_dir/elilo.conf
        # We need to set the GRUB environment variable 'root' to a reasonable default/fallback value
        # because GRUB's default 'root' (or GRUB's 'root' identifcation heuristics) would point to the ramdisk
        # but neither kernel nor initrd are located on the ramdisk but on the device where the recovery system was booted from.
        # GRUB2_SET_ROOT_COMMAND and/or GRUB2_SEARCH_ROOT_COMMAND is needed by the create_grub2_cfg() function.
        # Set GRUB2_SET_ROOT_COMMAND if not specified by the user:
        contains_visible_char "$GRUB2_SET_ROOT_COMMAND" || GRUB2_SET_ROOT_COMMAND="set root=cd0"
        create_grub2_cfg /isolinux/kernel /isolinux/$REAR_INITRD_FILENAME > $efi_boot_tmp_dir/grub.cfg
    fi
fi

if [[ -n "$(type -p grub)" ]]; then
    cat > $efi_boot_tmp_dir/BOOTX64.conf << EOF
default=0
timeout 5
splashimage=/EFI/BOOT/splash.xpm.gz
title Relax-and-Recover (no Secure Boot)
    kernel /isolinux/kernel $KERNEL_CMDLINE
    initrd /isolinux/$REAR_INITRD_FILENAME

EOF
else
    # Create a grub.cfg:
    # Sometimes the search command in GRUB2 used in UEFI ISO does not find the root device.
    # This was seen at least in Debian Buster running in Qemu
    # (VirtualBox works fine, RHEL/CentOS in Qemu works fine as well).
    # The GRUB2 image created by grub-mkstandalone has 'root' set to memdisk, which can't work.
    # To make ReaR work in this case, set 'root' to a sensible default value 'cd0'
    # before trying to search via GRUB2_SEARCH_ROOT_COMMAND in the create_grub2_cfg function
    # cf. https://github.com/rear/rear/issues/2434 and https://github.com/rear/rear/pull/2453
    # Set GRUB2_SET_ROOT_COMMAND and GRUB2_SEARCH_ROOT_COMMAND if not specified by the user:
    contains_visible_char "$GRUB2_SET_ROOT_COMMAND" || GRUB2_SET_ROOT_COMMAND="set root=cd0"
    contains_visible_char "$GRUB2_SEARCH_ROOT_COMMAND" || GRUB2_SEARCH_ROOT_COMMAND="search --no-floppy --set=root --file /boot/efiboot.img"
    create_grub2_cfg /isolinux/kernel /isolinux/$REAR_INITRD_FILENAME > $efi_boot_tmp_dir/grub.cfg
fi

# Create BOOTX86.efi but only if we are NOT secure booting.
# We are not able to create signed boot loader
# so we need to reuse existing one.
# See issue #1374
# build_bootx86_efi () can be safely used for other scenarios.
if ! test -f "$SECURE_BOOT_BOOTLOADER" ; then
    build_bootx86_efi $TMP_DIR/mnt/EFI/BOOT/BOOTX64.efi $efi_boot_tmp_dir/grub.cfg "$boot_dir" "$UEFI_BOOTLOADER"
fi

# We will be using grub-efi or grub2 (with efi capabilities) to boot from ISO.
# Because usr/sbin/rear sets 'shopt -s nullglob' the 'echo -n' command
# outputs nothing if nothing matches the bash globbing pattern '/boot/grub*'
local grubdir="$( echo -n ${boot_dir}/grub* )"
# Use '/boot/grub' as fallback if nothing matches '/boot/grub*'
test -d "$grubdir" || grubdir="${boot_dir}/grub"

local font_files_dir=""
local grub_font_files="no_fonts"
# When there are no font files in uefi_bootloader_dirname/fonts try grubdir/fonts as fallback:
for font_files_dir in $uefi_bootloader_dirname/fonts $grubdir/fonts ; do
    test -d $font_files_dir && grub_font_files="$( echo $font_files_dir/* )" || continue
    # Avoid 'nullglob' pitfall when nothing matches .../fonts/* which results
    # an invalid "cp -v /tmp/.../mnt/EFI/BOOT/fonts/" command that fails
    # cf. https://github.com/rear/rear/issues/1921
    if test "$grub_font_files" ; then
        cp $v $grub_font_files $efi_boot_tmp_dir/fonts/ && break || grub_font_files="no_fonts"
    fi
done
test "no_fonts" = "$grub_font_files" && LogPrintError "Warning: Did not find bootloader fonts (UEFI ISO boot may fail)"

# Avoid 'nullglob' pitfall when nothing matches .../locale/* which results
# an invalid "cp -v /tmp/.../mnt/EFI/BOOT/locale/" command that fails
# cf. https://github.com/rear/rear/issues/1921
local grub_locale_files="no_locales"
test -d $grubdir/locale && grub_locale_files="$( echo $grubdir/locale/* )"
test "$grub_locale_files" && cp $v $grub_locale_files $efi_boot_tmp_dir/locale/ || grub_locale_files="no_locales"
test "no_locales" = "$grub_locale_files" && LogPrint "Did not find $grubdir/locale files (minor issue for UEFI ISO boot)"

# Copy of efiboot content also the our ISO tree (isofs/)
mkdir $v -p -m 755 $TMP_DIR/isofs/EFI/BOOT
cp $v -r $TMP_DIR/mnt/EFI $TMP_DIR/isofs/ || Error "Could not create the isofs/EFI/BOOT directory on the ISO image"

# Make /boot/grub/grub.cfg available on isofs/
mkdir $v -p -m 755 $TMP_DIR/isofs/boot/grub
if test "$( type -p grub )" ; then
    cp $v $TMP_DIR/isofs/EFI/BOOT/BOOTX64.conf $TMP_DIR/isofs/boot/grub/ || Error "Could not copy EFI/BOOT/BOOTX64.conf to isofs/boot/grub"
else
    cp $v $TMP_DIR/isofs/EFI/BOOT/grub.cfg $TMP_DIR/isofs/boot/grub/ || Error "Could not copy EFI/BOOT/grub.cfg to isofs/boot/grub"
fi
