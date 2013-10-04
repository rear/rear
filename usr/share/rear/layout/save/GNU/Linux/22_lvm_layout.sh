# Save LVM layout

if ! has_binary lvm; then
    return
fi

Log "Saving LVM layout."

(
    ## Get physical_device configuration
    # format: lvmdev <volume_group> <device> [<uuid>] [<size(bytes)>]
    lvm 8>&- 7>&- pvdisplay -c | while read line ; do
        pdev=$(echo $line | cut -d ":" -f "1")

        if [ "${pdev#/}" = "$pdev" ] ; then
            # Skip lines that are not describing physical devices
            continue
        fi

        vgrp=$(echo $line | cut -d ":" -f "2")
        size=$(echo $line | cut -d ":" -f "3")
        uuid=$(echo $line | cut -d ":" -f "12")

        pdev=$(get_device_mapping $pdev)  # xlate through diskbyid_mappings file
        echo "lvmdev /dev/$vgrp $(get_device_name $pdev) $uuid $size"
    done

    ## Get the volume group configuration
    # format: lvmgrp <volume_group> <extentsize> [<size(extents)>] [<size(bytes)>]
    lvm 8>&- 7>&- vgdisplay -c | while read line ; do
        vgrp=$(echo $line | cut -d ":" -f "1")
        size=$(echo $line | cut -d ":" -f "12")
        extentsize=$(echo $line | cut -d ":" -f "13")
        nrextents=$(echo $line | cut -d ":" -f "14")

        echo "lvmgrp /dev/$vgrp $extentsize $nrextents $size"
    done

    ## Get all logical volumes
    # format: lvmvol <volume_group> <name> <size(extents)> [<size(bytes)>]
    lvm 8>&- 7>&- lvdisplay -c | while read line ; do
        lvol=$(echo $line | cut -d ":" -f "1" | cut -d "/" -f "4")
        vgrp=$(echo $line | cut -d ":" -f "2")
        size=$(echo $line | cut -d ":" -f "7")
        extents=$(echo $line | cut -d ":" -f "8")

        echo "lvmvol /dev/$vgrp $lvol $extents $size "
    done
) >> $DISKLAYOUT_FILE
