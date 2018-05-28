# Save LVM layout

if ! has_binary lvm; then
    return
fi

Log "Saving LVM layout."

(
    header_printed=0

    ## Get physical_device configuration
    # format: lvmdev <volume_group> <device> [<uuid>] [<size(bytes)>]
    lvm 8>&- 7>&- pvdisplay -c | while read line ; do
        pdev=$(echo $line | cut -d ":" -f "1")

        if [ "${pdev#/}" = "$pdev" ] ; then
            # Skip lines that are not describing physical devices
            continue
        fi

        if [ $header_printed -eq 0 ] ; then
            echo "# Format for LVM PVs"
            echo "# lvmdev <volume_group> <device> [<uuid>] [<size(bytes)>]"
            header_printed=1
        fi

        vgrp=$(echo $line | cut -d ":" -f "2")
        size=$(echo $line | cut -d ":" -f "3")
        uuid=$(echo $line | cut -d ":" -f "12")

        pdev=$(get_device_mapping $pdev)  # xlate through diskbyid_mappings file
        echo "lvmdev /dev/$vgrp $(get_device_name $pdev) $uuid $size"
    done

    header_printed=0

    ## Get the volume group configuration
    # format: lvmgrp <volume_group> <extentsize> [<size(extents)>] [<size(bytes)>]
    lvm 8>&- 7>&- vgdisplay -c | while read line ; do
        vgrp=$(echo $line | cut -d ":" -f "1")
        size=$(echo $line | cut -d ":" -f "12")
        extentsize=$(echo $line | cut -d ":" -f "13")
        nrextents=$(echo $line | cut -d ":" -f "14")

        if [ $header_printed -eq 0 ] ; then
            echo "# Format for LVM VGs"
            echo "# lvmgrp <volume_group> <extentsize> [<size(extents)>] [<size(bytes)>]"
            header_printed=1
        fi

        echo "lvmgrp /dev/$vgrp $extentsize $nrextents $size"
    done

    header_printed=0

    ## Get all logical volumes
    # format: lvmvol <volume_group> <name> <size(bytes)> <layout> [key:value ...]

    # Check for 'lvs' support of lv_layout

    if lvm lvs -o lv_layout >/dev/null 2>&1; then

        lvm 8>&- 7>&- lvs --separator=":" --noheadings --units b --nosuffix -o origin,lv_name,vg_name,lv_size,lv_layout,pool_lv,chunk_size,stripes,stripe_size | while read line ; do

            if [ $header_printed -eq 0 ] ; then
                echo "# Format for LVM LVs"
                echo "# lvmvol <volume_group> <name> <size(bytes)> <layout> [key:value ...]"
                header_printed=1
            fi

            origin="$(echo "$line" | awk -F ':' '{ print $1 }')"
            # Skip snapshots (useless) or caches (dont know how to handle that)
            if [ -n "$origin" ] ; then
                echo "# Skipped snapshot of cache information '$line'"
                continue
            fi

            lv="$(echo "$line" | awk -F ':' '{ print $2 }')"
            vg="$(echo "$line" | awk -F ':' '{ print $3 }')"
            size="$(echo "$line" | awk -F ':' '{ print $4 }')"
            layout="$(echo "$line" | awk -F ':' '{ print $5 }')"
            thinpool="$(echo "$line" | awk -F ':' '{ print $6 }')"
            chunksize="$(echo "$line" | awk -F ':' '{ print $7 }')"
            stripes="$(echo "$line" | awk -F ':' '{ print $8 }')"
            stripesize="$(echo "$line" | awk -F ':' '{ print $9 }')"

            kval=""
            [ -z "$thinpool" ] || kval="${kval:+$kval }thinpool:$thinpool"
            [ $chunksize -eq 0 ] || kval="${kval:+$kval }chunksize:${chunksize}b"
            [ $stripesize -eq 0 ] || kval="${kval:+$kval }stripesize:${stripesize}b"
            if [[ ,$layout, == *,mirror,* ]] ; then
                kval="${kval:+$kval }mirrors:$(($stripes - 1))"
            elif [[ ,$layout, == *,striped,* ]] ; then
                kval="${kval:+$kval }stripes:$stripes"
            fi

            echo "lvmvol /dev/$vg $lv ${size}b $layout $kval"
        done

    else
        # Compatibility with older LVM versions (e.g. <= 2.02.98)
        # No support for 'lv_layout', too bad, do our best!

        lvm 8>&- 7>&- lvs --separator=":" --noheadings --units b --nosuffix -o origin,lv_name,vg_name,lv_size,modules,pool_lv,chunk_size,stripes,stripe_size | while read line ; do

            if [ $header_printed -eq 0 ] ; then
                echo "# Format for LVM LVs"
                echo "# lvmvol <volume_group> <name> <size(bytes)> <layout> [key:value ...]"
                header_printed=1
            fi

            origin="$(echo "$line" | awk -F ':' '{ print $1 }')"
            # Skip snapshots (useless) or caches (dont know how to handle that)
            if [ -n "$origin" ] ; then
                echo "# Skipped snapshot of cache information '$line'"
                continue
            fi

            lv="$(echo "$line" | awk -F ':' '{ print $2 }')"
            vg="$(echo "$line" | awk -F ':' '{ print $3 }')"
            size="$(echo "$line" | awk -F ':' '{ print $4 }')"
            modules="$(echo "$line" | awk -F ':' '{ print $5 }')"
            thinpool="$(echo "$line" | awk -F ':' '{ print $6 }')"
            chunksize="$(echo "$line" | awk -F ':' '{ print $7 }')"
            stripes="$(echo "$line" | awk -F ':' '{ print $8 }')"
            stripesize="$(echo "$line" | awk -F ':' '{ print $9 }')"

            kval=""
            [ -z "$thinpool" ] || kval="${kval:+$kval }thinpool:$thinpool"
            [ $chunksize -eq 0 ] || kval="${kval:+$kval }chunksize:${chunksize}b"
            [ $stripesize -eq 0 ] || kval="${kval:+$kval }stripesize:${stripesize}b"
            if [[ "$modules" == "" ]] ; then
                layout="linear"
                [ $stripes -eq 0 ] || kval="${kval:+$kval }stripes:$stripes"
            elif [[ ,$modules, == *,mirror,* ]] ; then
                layout="mirror"
                kval="${kval:+$kval }mirrors:$(($stripes - 1))"
            elif [[ ,$modules, == *,thin-pool,* ]] ; then
                if [ -z "$thinpool" ] ; then
                    layout="thin,pool"
                else
                    layout="thin,sparse"
                fi
            elif [[ ,$modules, == *,raid,* ]] ; then
                LogPrint "Warning: don't know how to collect RAID information for LV '$lv'. Automatic disk layout recovery may fail."
                layout="raid,RAID_UNKNOWNTYPE"
                kval="${kval:+$kval }stripes:$stripes"
            fi

            echo "lvmvol /dev/$vg $lv ${size}b $layout $kval"
        done

    fi

) >> $DISKLAYOUT_FILE

# vim: set et ts=4 sw=4:
