# When /boot/efi is mounted we copy the UEFI binaries we might need

# If noefi is set, we can ignore UEFI altogether
if grep -qw 'noefi' /proc/cmdline; then
    return
fi

# next step, is checking /boot/efi directory case-insensitive for the /EFI part (we need it)
if [[ $(find /boot -maxdepth 1 -iname efi -type d | wc -l) -eq 0 ]] ; then
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
