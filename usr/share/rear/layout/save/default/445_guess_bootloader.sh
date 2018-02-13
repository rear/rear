
# Determine or guess the used bootloader if not specified by the user
# and save this information into /var/lib/rear/recovery/bootloader
bootloader_file="$VAR_DIR/recovery/bootloader"

# When BOOTLOADER is specified use that:
if test "$BOOTLOADER" ; then
    LogPrint "Using specified bootloader '$BOOTLOADER'"
    echo "$BOOTLOADER" | tr '[a-z]' '[A-Z]' >$bootloader_file
    return
fi

# When a bootloader is specified in /etc/sysconfig/bootloader use that:
if test -f /etc/sysconfig/bootloader ; then
    # SUSE uses LOADER_TYPE, and others?
    # Getting values from sysconfig files is like sourcing shell scripts so that the last setting wins:
    sysconfig_bootloader=$( grep ^LOADER_TYPE /etc/sysconfig/bootloader | cut -d= -f2 | tail -n1 | sed -e 's/"//g' )
    if test "$sysconfig_bootloader" ; then
        LogPrint "Using sysconfig bootloader '$sysconfig_bootloader'"
        echo "$sysconfig_bootloader" | tr '[a-z]' '[A-Z]' >$bootloader_file
        return
    fi
fi

# On ARM, guess the dummy bootloader:
if [ "$ARCH" = "Linux-arm" ]; then
    BOOTLOADER=ARM
    # Inform the user that we do nothing:
    LogPrint "Using guessed bootloader 'ARM'
Skipping bootloader backup, see default.conf"
    echo "$BOOTLOADER" >$bootloader_file
    return
fi

# Finally guess the used bootloader by inspecting the first bytes on all disks
# and use the first one that matches a known bootloader string:
for block_device in /sys/block/* ; do
    blockd=${block_device#/sys/block/}
    # Continue with the next block device when the current block device is not a disk that can be used for booting:
    [[ $blockd = hd* || $blockd = sd* || $blockd = cciss* || $blockd = vd* || $blockd = xvd* || $blockd = nvme* || $blockd = mmcblk* || $blockd = dasd*  ]] || continue
    disk_device=$( get_device_name $block_device )
    # Check if the disk contains a PPC PreP boot partition (ID=0x41)
    if file -s $disk_device | grep -q "ID=0x41" ; then
       LogPrint "Using PreP boot partition bootloader 'PPC'"
       echo "PPC" >$bootloader_file
       return
    fi
    # Get all strings in the first 512*4=2048 bytes on the disk:
    bootloader_area_strings_file="$TMP_DIR/bootloader_area_strings"
    block_size=$( get_block_size ${disk_device##*/} )
    dd if=$disk_device bs=$block_size count=4 | strings >$bootloader_area_strings_file
    # Examine the strings in the first bytes on the disk to guess the used bootloader,
    # see layout/save/default/450_check_bootloader_files.sh for the known bootloaders.
    # Test the more specific strings first because the first match wins:
    for known_bootloader in GRUB2-EFI EFI GRUB2 GRUB ELILO LILO ; do
        if grep -q -i "$known_bootloader" $bootloader_area_strings_file ; then
            LogPrint "Using guessed bootloader '$known_bootloader'"
            echo "$known_bootloader" >$bootloader_file
            return
        fi
    done
    # When no known bootloader matches the first bytes on the current disk
    # log all strings in the first bytes on the current disk
    # so that the user can see the results in the log file:
    Log "No known bootloader matches the first bytes on $disk_device"
    Log "Begin of strings in the first bytes on $disk_device"
    cat $bootloader_area_strings_file >&2
    Log "End of strings in the first bytes on $disk_device"
done


# Error out when no bootloader was specified or could be autodetected:
Error "Cannot autodetect what is used as bootloader, see default.conf about 'BOOTLOADER'"

