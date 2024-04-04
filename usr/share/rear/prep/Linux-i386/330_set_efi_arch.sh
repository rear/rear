
# Set EFI architecture, used as suffix for various files in the ESP
# See https://github.com/rhboot/shim/blob/main/Make.defaults

# Se the variables even if USING_UEFI_BOOTLOADER empty or no explicit 'true' value

case "$REAL_MACHINE" in
    # cf. the seting of REAL_MACHINE and MACHINE in default.conf
    (i686|i586|i386)
        # all these behave exactly like i386.
        # ia32 is another name for i386, used by EFI
        # (but ia64 is not x86_64 aka amd64, it is the architecture of Itanium)
        EFI_ARCH=ia32
        # argument for grub2-mkstandalone -O ...
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
