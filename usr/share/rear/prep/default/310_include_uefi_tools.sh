# If noefi is set, we can ignore UEFI altogether
if grep -qw 'noefi' /proc/cmdline; then
    return
fi

# If no /boot/[eE][fF][iI] directory can be found we might not be able to copy the UEFI binaries.
if [[ ! -d /boot/[eE][fF][iI] || ! mountpoint -q /boot/[eE][fF][iI] ]]; then
    if is_true $USING_UEFI_BOOTLOADER; then
        Error "USING_UEFI_BOOTLOADER = 1 but there is no directory at /boot/efi or /boot/EFI" # abort
    fi
    return # skip
fi

# We copy the UEFI binaries we might need
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
