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
    # format: lvmvol <volume_group> <name> <size(bytes)> <layout> [key:value ...]

    lvm 8>&- 7>&- lvs --separator=":" --noheadings --units b --nosuffix -o origin,lv_name,vg_name,lv_size,lv_layout,pool_lv,chunk_size,stripes | while read line ; do
        origin=$(echo $line | awk -F ':' '{ print $1 }')
        # Skip snapshots
        [ -z "$origin" ] || continue

        lv=$(echo $line | awk -F ':' '{ print $2 }')
        vg=$(echo $line | awk -F ':' '{ print $3 }')
        size=$(echo $line | awk -F ':' '{ print $4 }')
        layout=$(echo $line | awk -F ':' '{ print $5 }')
        thinpool=$(echo $line | awk -F ':' '{ print $6 }')
        chunksize=$(echo $line | awk -F ':' '{ print $7 }')
        stripes=$(echo $line | awk -F ':' '{ print $8 }')

        kval=""
        [ -z "$thinpool" ] || kval="${kval:+$kval }thinpool:$thinpool"
        [ $chunksize -eq 0 ] || kval="${kval:+$kval }chunksize:${chunksize}b"
        [[ ,$layout, != ,mirror, ]] || kval="${kval:+$kval }mirrors:$(($stripes - 1))"

        echo "lvmvol /dev/$vg $lv ${size}b $layout $kval"
    done
) >> $DISKLAYOUT_FILE

# vim: set et ts=4 sw=4:
