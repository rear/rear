# Save swaps

LogPrint "Saving Swap information."

(
    while read filename type junk ; do
        if [ "$filename" = "Filename" ] || [ "$type" = "file" ] ; then
            continue
        fi
        # if filename is on a lv, try to find the DM name
        for dlink in $(ls /dev/mapper/*) ; do
            target=$(readlink -f $dlink)
            if [ "$target" = "$filename" ] ; then
                filename=$dlink
                break
            fi
        done
        
        # find uuid or label
        if type swaplabel &>/dev/null ; then
            while read what value junk; do
                case $what in
                    UUID:)
                        uuid=$value
                        ;;
                    LABEL:)
                        label=$value
                        ;;
                esac
            done < <(swaplabel $filename)
        fi
        
        echo "swap $filename uuid=$uuid label=$label"
    done < <(cat /proc/swaps)
) >> $DISKLAYOUT_FILE
