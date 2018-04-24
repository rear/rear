
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
if [ "$ARCH" = "Linux-arm" ] ; then
    BOOTLOADER=ARM
    # Inform the user that we do nothing:
    LogPrint "Using guessed bootloader 'ARM'. Skipping bootloader backup, see default.conf"
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
    # Check if the disk contains a PPC PreP boot partition (ID=0x41):
    if file -s $disk_device | grep -q "ID=0x41" ; then
       LogPrint "Using guessed bootloader 'PPC' (found PPC PreP boot partition 'ID=0x41' on $disk_device)"
       echo "PPC" >$bootloader_file
       return
    fi
    # Get all strings in the first 512*4=2048 bytes on the disk:
    bootloader_area_strings_file="$TMP_DIR/bootloader_area_strings"
    block_size=$( get_block_size ${disk_device##*/} )
    dd if=$disk_device bs=$block_size count=4 | strings >$bootloader_area_strings_file
    # Examine the strings in the first bytes on the disk to guess the used bootloader,
    # see layout/save/default/450_check_bootloader_files.sh for the known bootloaders.
    # Test the more specific strings first because the first match wins.
    # Skip LUKS encrypted disks when guessing bootloader:
    if grep -q "LUKS" $bootloader_area_strings_file ; then
        LogPrint "Cannot autodetect bootloader on LUKS encrypted disk (found 'LUKS' in first bytes on $disk_device)"
        # Continue guessing the used bootloader by inspecting the first bytes on the next disk:
        continue
    fi
    # 'Hah!IdontNeedEFI' is the ASCII representation of the official GUID number
    # for a GPT BIOS boot partition which is 21686148-6449-6E6F-744E-656564454649
    # see https://en.wikipedia.org/wiki/BIOS_boot_partition (issue #1752).
    # Use single quotes for 'Hah!IdontNeedEFI' to be on the safe side
    # because with double quotes the ! would cause history expansion if that is enabled
    # (non-interactive shells do not perform history expansion by default but better safe than sorry):
    if grep -q 'Hah!IdontNeedEFI' $bootloader_area_strings_file ; then
        # Because 'Hah!IdontNeedEFI' contains the known bootloader 'EFI'
        # the default code below would falsely guess that 'EFI' is used
        # but actually another non-EFI bootloader is used here
        # cf. https://github.com/rear/rear/issues/1752#issue-303856221
        # so that in the 'Hah!IdontNeedEFI' case only non-EFI bootloaders are tested:
        for known_bootloader in GRUB2 GRUB ELILO LILO ; do
            if grep -q -i "$known_bootloader" $bootloader_area_strings_file ; then
                LogPrint "Using guessed bootloader '$known_bootloader' (found in first bytes on $disk_device with GPT BIOS boot partition)"
                echo "$known_bootloader" >$bootloader_file
                return
            fi
        done
        # When in the 'Hah!IdontNeedEFI' case no known non-EFI bootloader is found
        # continue guessing the used bootloader by inspecting the first bytes on the next disk
        # because otherwise the default code below would falsely guess that 'EFI' is used
        # cf. https://github.com/rear/rear/pull/1754#issuecomment-383531597
        continue
    fi
    # Check the default cases of known bootloaders:
    for known_bootloader in GRUB2-EFI EFI GRUB2 GRUB ELILO LILO ; do
        if grep -q -i "$known_bootloader" $bootloader_area_strings_file ; then
            LogPrint "Using guessed bootloader '$known_bootloader' (found in first bytes on $disk_device)"
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

