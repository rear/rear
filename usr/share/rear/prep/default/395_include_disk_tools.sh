# Include disk tools

function partuuid_restoration_is_required() {
    local cfgs=(
        /boot/grub/grub.cfg
        /boot/grub2/grub.cfg
        /boot/loader/entries/
        /etc/fstab
    )

    for cfg in "${cfgs[@]}"; do
        if test -e "$cfg" && grep -qr "PARTUUID=" "$cfg"; then
            return 0
        fi
    done

    return 1
}

# In cases when PARTUUIDs are used to tell the Linux kernel where the root
# filesystem live, e.g.,
#     linux /vmlinuz-... root=PARTUUID=<partition uuid>
# or when they are used in /etc/fstab to mount devices, e.g.,
#     PARTUUID=<partition uuid> /boot xfs defaults 0 0
# changing PARTUUIDs during recovery may lead to a non-bootable system.
# Therefore, in these cases, PARTUUID restoration is required, and the sgdisk
# tool, which is used to change PARTUUID during the layout/recreation stage,
# must be available on the recovery system.
#
# In other cases, PARTUUID restoration considered as a nice-to-have and,
# sgdisk is optional.
if partuuid_restoration_is_required; then
    REQUIRED_PROGS+=( sgdisk )
else
    PROGS+=( sgdisk )
fi
