#
# Copy UEFI binaries we might need into the ReaR recovery system.
#

# Include UEFI tools on demand only
is_true $USING_UEFI_BOOTLOADER || return

# Copy UEFI binaries we might need:
REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" dosfsck efibootmgr )
PROGS=( "${PROGS[@]}" gdisk parted uefivars )
MODULES=( "${MODULES[@]}" efivars )
if test -f /sbin/elilo ; then
    # this is probably SLES
    PROGS=( "${PROGS[@]}" elilo perl )
    COPY_AS_IS=( "${COPY_AS_IS[@]}"
                 /etc/elilo.conf
                 /usr/lib64/crt0-efi-x86_64.o
                 /usr/lib64/elf_x86_64_efi.lds
                 /usr/lib64/libefi.a
                 /usr/lib64/libgnuefi.a )
fi
