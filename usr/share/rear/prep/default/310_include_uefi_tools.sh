# If noefi is set, we can ignore UEFI altogether
if grep -qw 'noefi' /proc/cmdline; then
    return
fi

# When /boot/[eE][fF][iI] is found (mounted) we copy the UEFI binaries we might need
if [[ ! -d /boot/[eE][fF][iI] ]]; then
    if [[ $USING_UEFI_BOOTLOADER == 1 ]]; then
        Error "USING_UEFI_BOOTLOADER = 1 but there is no directory at /boot/efi or /boot/EFI"
    fi
    return    # must be mounted
fi

REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}"
dosfsck
efibootmgr
)

PROGS=( "${PROGS[@]}"
gdisk
parted
uefivars
)

MODULES=( "${MODULES[@]}" efivars )

if [[ -f /sbin/elilo ]]; then
    # this is probably SLES
    PROGS=( "${PROGS[@]}" elilo perl )
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/elilo.conf /usr/lib64/crt0-efi-x86_64.o /usr/lib64/elf_x86_64_efi.lds \
    /usr/lib64/libefi.a /usr/lib64/libgnuefi.a )
fi
