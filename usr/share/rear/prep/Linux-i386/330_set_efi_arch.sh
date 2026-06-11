
# Set EFI architecture, used as suffix for various files in the ESP
# See https://github.com/rhboot/shim/blob/main/Make.defaults

# Set the variables even if USING_UEFI_BOOTLOADER empty or no explicit 'true' value
# which sets GRUB2_IMAGE_FORMAT (used as argument for 'grub-mkstandalone -O ...')
# to a value for EFI systems ('x86_64-efi' or 'i386-efi') also on BIOS systems
# but that does not matter for now because currently GRUB2_IMAGE_FORMAT
# is only used in case of EFI in the scripts lib/uefi-functions.sh
# and output/RAWDISK/Linux-i386/270_create_grub2_efi_bootloader.sh
# see https://github.com/rear/rear/pull/3157
# and https://github.com/rear/rear/issues/3191
# and https://github.com/rear/rear/issues/3195

case "$REAL_MACHINE" in
    # cf. the setting of REAL_MACHINE ('uname -m') and MACHINE in default.conf
    (i686|i586|i386)
        # all these behave exactly like i386.
        # ia32 is another name for i386, used by EFI
        # (but ia64 is not x86_64 aka amd64, it is the architecture of Itanium)
        EFI_ARCH=ia32
        GRUB2_IMAGE_FORMAT=i386-efi
        ;;
    (x86_64)
        EFI_ARCH=x64
        GRUB2_IMAGE_FORMAT=x86_64-efi
        ;;
    (*)
        BugError "Unknown architecture $REAL_MACHINE"
esac

EFI_ARCH_UPPER="${EFI_ARCH^^}"
