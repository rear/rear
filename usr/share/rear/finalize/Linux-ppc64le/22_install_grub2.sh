#  This  script is an improvement over the default grub-install '(hd0)'
#
# However the following issues still exist:
#
#  * We don't know what the first disk will be, so we cannot be sure the MBR
#    is written to the correct disk(s). That's why we make all disks bootable.
#
#  * There is no guarantee that GRUB was the boot loader used originally. One
#    solution is to save and restore the MBR for each disk, but this does not
#    guarantee a correct boot-order, or even a working boot-lader config (eg.
#    GRUB stage2 might not be at the exact same location)

# skip if another bootloader was installed
if [[ -z "$NOBOOTLOADER" ]] ; then
    return
fi

# Only for GRUB2 - GRUB Legacy will be handled by its own script
[[ $(type -p grub-probe) || $(type -p grub2-probe) ]] || return

LogPrint "Installing GRUB2 boot loader"
mount -t proc none /mnt/local/proc

if [[ -r "$LAYOUT_FILE" ]]; then

    # Check if we find GRUB where we expect it
    [[ -d "/mnt/local/boot" ]]
    StopIfError "Could not find directory /boot"

    # grub2 can be in /boot/grub or /boot/grub2
    grub_name="grub2"
    if [[ ! -d "/mnt/local/boot/$grub_name" ]] ; then
        grub_name="grub"
        [[ -d "/mnt/local/boot/$grub_name" ]]
        StopIfError "Could not find directory /boot/$grub_name"
    fi
    [[ -r "/mnt/local/boot/$grub_name/grub.cfg" ]]
    LogIfError "Unable to find /boot/$grub_name/grub.cfg."

    # Find PPC PReP Boot partition 
    part=`awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $LAYOUT_FILE`

    if [ -n "$part" ]; then
        LogPrint "Boot partition found: $part"
        chroot /mnt/local /bin/bash --login -c "$grub_name-install $part"
        # Run bootlist only in PowerVM environment
        if ! grep -q "PowerNV" /proc/cpuinfo && ! grep -q "emulated by qemu" /proc/cpuinfo ; then
            bootdev=`echo $part | sed -e 's/[0-9]*$//'`
            LogPrint "Boot device is $bootdev."
            bootlist -m normal $bootdev
        fi
        NOBOOTLOADER=
    fi
fi

if [[ "NOBOOTLOADER" ]]; then
    LogIfError "No bootloader configuration found. Install boot partition manually"
fi    

#for i in /dev /dev/pts /proc /sys; do umount  /mnt/local${i} ; done
umount /mnt/local/proc
