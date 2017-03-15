# When /boot/efi is mounted we copy the UEFI binaries we might need

# If noefi is set, we can ignore UEFI altogether
if grep -qw 'noefi' /proc/cmdline; then
    return
fi

# Next step, is checking /boot/efi directory case-insensitive for the /EFI part (we need it).
# If no /boot/[eE][fF][iI] directory can be found we cannot copy the UEFI binaries we might need.
# TODO: I <jsmeix@suse.de> wonder if plain silent 'return' really the right way out here
# or whether there should be some more checks? Perhaps having access to the UEFI binaries
# is sometimes mandatory so that ReaR might then better abort with a clear Error message
# instead of proceeding 'bona fide' here?
test "$( find /boot -maxdepth 1 -iname efi -type d )" || return

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
