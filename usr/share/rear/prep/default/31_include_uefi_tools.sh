# When /boot/efi is mounted we copy the UEFI binaries we might need

# If noefi is set, we can ignore UEFI altogether
if grep -qw 'noefi' /proc/cmdline; then
    return
fi

# next step, is checking /boot/efi directory (we need it)
if [[ ! -d /boot/efi ]]; then
    return    # must be mounted
fi

PROGS=( "${PROGS[@]}"
dosfsck
dosfslabel
efibootmgr
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
