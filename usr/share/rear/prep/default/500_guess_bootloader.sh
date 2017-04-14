# purpose is to guess the bootloader in use ans save this into a file
# /var/lib/rear/recovery/bootloader
if [[ -f /etc/sysconfig/bootloader ]]; then
    # openSUSE uses LOADER_TYPE, and others??
    # getting values from sysconfig files is like sourcing shell scripts so that the last setting wins
    my_bootloader=$( grep ^LOADER_TYPE /etc/sysconfig/bootloader | cut -d= -f2 | tail -n1 | sed -e 's/"//g' )
    if [[ ! -z "$my_bootloader" ]]; then
        echo "$my_bootloader" | tr '[a-z]' '[A-Z]' >$VAR_DIR/recovery/bootloader
        return
    fi
fi
for disk in /sys/block/* ; do
    blockd=${disk#/sys/block/}
    if [[ $blockd = hd* || $blockd = sd* || $blockd = cciss* || $blockd = vd* || $blockd = xvd* || $blockd = nvme* || $blockd = dasd*  ]] ; then
        devname=$(get_device_name $disk)

        # Check if devname contains a PPC PreP boot partition (ID=0x41)
        if $(file -s $devname | grep ID=0x41 >/dev/null) ; then
           echo "PPC" >$VAR_DIR/recovery/bootloader
           return
        fi

        dd if=$devname bs=512 count=4 | strings > $TMP_DIR/bootloader
        grep -q "EFI" $TMP_DIR/bootloader && {
        echo "EFI" >$VAR_DIR/recovery/bootloader
        return
        }
        grep -q "GRUB" $TMP_DIR/bootloader && {
        echo "GRUB" >$VAR_DIR/recovery/bootloader
        return
        }
        grep -q "LILO" $TMP_DIR/bootloader && {
        echo "LILO" >$VAR_DIR/recovery/bootloader
        return
        }
        Log "Displaying the raw bootloader info of device $devname:"
        cat $TMP_DIR/bootloader >&2
   fi
done
