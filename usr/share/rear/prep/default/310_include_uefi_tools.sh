#
# 310_include_uefi_tools.sh
# Copy UEFI binaries we might need into the ReaR recovery system.
#

# If 'noefi' is set on the kernel commandline, ignore UEFI altogether:
grep -qw 'noefi' /proc/cmdline && return

# If no /boot/[eE][fF][iI] directory can be found
# we might not be able to copy the UEFI binaries:
if ! test -d /boot/[eE][fF][iI] ; then
    if is_true $USING_UEFI_BOOTLOADER; then
        Error "USING_UEFI_BOOTLOADER is set but there is no directory /boot/efi or /boot/EFI"
    fi
    return
fi

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
