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
mount -t proc none $TARGET_FS_ROOT/proc

if [[ -r "$LAYOUT_FILE" ]]; then

    # Check if we find GRUB where we expect it
    [[ -d "$TARGET_FS_ROOT/boot" ]]
    StopIfError "Could not find directory /boot"

    # grub2 can be in /boot/grub or /boot/grub2
    grub_name="grub2"
    if [[ ! -d "$TARGET_FS_ROOT/boot/$grub_name" ]] ; then
        grub_name="grub"
        [[ -d "$TARGET_FS_ROOT/boot/$grub_name" ]]
        StopIfError "Could not find directory /boot/$grub_name"
    fi
    [[ -r "$TARGET_FS_ROOT/boot/$grub_name/grub.cfg" ]]
    LogIfError "Unable to find /boot/$grub_name/grub.cfg."

    # Find PPC PReP Boot partition
    part=$( awk -F ' ' '/^part / {if ($6 ~ /prep/) {print $7}}' $LAYOUT_FILE )

    if [ -n "$part" ]; then
        LogPrint "Boot partition found: $part"
        dd if=/dev/zero of=$part
        chroot $TARGET_FS_ROOT /bin/bash --login -c "$grub_name-install $part"
        # Run bootlist only in PowerVM environment
        if ! grep -q "PowerNV" /proc/cpuinfo && ! grep -q "emulated by qemu" /proc/cpuinfo ; then
            #Using $LAYOUT_DEPS file to find the disk device containing the partition.
            bootdev=$(awk '$1==PART { print $NF}' PART=$part $LAYOUT_DEPS)
            if [[ -z $bootdev ]]; then
                bootdev=`echo $part | sed -e 's/[0-9]*$//'`
            fi
            LogPrint "Boot device is $bootdev."

            # Test if $bootdev is a multipath device
            if dmsetup ls --target multipath | grep -w ${bootdev#/dev/mapper/} >/dev/null 2>&1; then
                LogPrint "Limiting bootlist to 5 entries..."
                bootlist_path=$(dmsetup deps $bootdev -o devname | awk -F: '{gsub (" ",""); gsub("\\(","/dev/",$2) ; gsub("\\)"," ",$2) ; print $2}' | cut -d" " -f-5)
                LogPrint "bootlist will be $bootlist_path"
                bootlist -m normal $bootlist_path
                LogIfError "Unable to set bootlist. You will have to start in SMS to set it up manually."
            else
                LogPrint "bootlist will be $bootdev"
                bootlist -m normal $bootdev
            fi
        fi
        NOBOOTLOADER=
    fi
fi

if [[ "NOBOOTLOADER" ]]; then
    LogIfError "No bootloader configuration found. Install boot partition manually"
fi

umount $TARGET_FS_ROOT/proc
