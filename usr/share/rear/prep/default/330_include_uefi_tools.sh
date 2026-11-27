#
# Copy UEFI binaries we might need into the ReaR recovery system.
#

# Include UEFI tools on demand only
is_true $USING_UEFI_BOOTLOADER || return 0

# Copy UEFI binaries we might need:
REQUIRED_PROGS+=( dosfsck efibootmgr )
PROGS+=( gdisk parted uefivars )
MODULES+=( efivars )

