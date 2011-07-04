# Collect HP Smartarray information

if ! has_binary hpacucli; then
    return
fi

# Add hpacucli to the rescue image
PROGS=( "${PROGS[@]}" hpacucli )
eval $(grep ON_DIR= $(get_path hpacucli))
COPY_AS_IS=( "${COPY_AS_IS[@]}" "$HPACUCLI_BIN_INSTALLATION_DIR" )

Log "Saving HP SmartArray configuration."

### In case we have a controller problem, the hpacucli output may not reflect
### the actual configuration of the system, and hence the layout output could
### be incorrect ! Fail if this is the case !
hpacucli ctrl all show detail > $TMP_DIR/hpraid-detail.tmp
grep 'Controller Status:' $TMP_DIR/hpraid-detail.tmp | grep -v 'Controller Status: OK'
if (( $? != 1 )); then
    Error "One or more HP SmartArray controllers have errors, fix this first !"
fi

hpacucli ctrl all show config > $TMP_DIR/hpraid-config.tmp

# a list of all non-empty controllers
controllers=()

write_logicaldrive() {
    if [ -n "$drives" ] ; then
        echo "logicaldrive $devname $slotnr|$arrayname|$ldname raid=$raidlevel drives=$drives spares=$spares sectors=$sectors stripesize=$stripesize" >> $DISKLAYOUT_FILE
        # We only want controllers that have a logical drive in the layout file.
        if ! IsInArray "$slotnr" "${controllers[@]}" ; then
            controllers=( "${controllers[@]}" "$slotnr" )
        fi
    fi
    drives=""
    spares=""
}

drives=
spares=
while read line ; do
    case $line in
        *Slot*)
            nextslotnr=$(echo "$line" | sed -r 's/.*Slot ([0-9]).*/\1/')
            ;;
        *array*)
            nextarrayname=$(echo "$line" | sed -r 's/.*array ([A-Z]).*/\1/')
            ;;
        *logicaldrive*)
            # Write previously found logical drive
            write_logicaldrive
            slotnr=$nextslotnr
            arrayname=$nextarrayname

            # Create new Logical drive
            drivedetails=$(echo "$line" | sed -r 's/.*logicaldrive ([^ ]+) .*RAID ([^ ,]+)[ ,]+.*/\1 \2/')
            raidlevel=${drivedetails#* }
            ldname=${drivedetails% *}

            tmpfile=$TMP_DIR/ctrl$slotnr-$ldname.tmp
            hpacucli ctrl slot=$slotnr ld $ldname show detail > $tmpfile
            stripesize=$(grep -i "stripe" $tmpfile | sed -r "s/[^0-9]+([0-9]+).*/\1/")
            sectors=$(grep -i "sectors" $tmpfile | sed -r "s/[^0-9]+([0-9]+).*/\1/")
            devname=$(grep -i "name" $tmpfile | cut -d ":" -f "2" | tr -d " ")
            ;;
        *physicaldrive*)
            if [ -n "$arrayname" ] ; then
                pdname=$(echo "$line" | sed -r 's/.*physicaldrive ([^ ]+) .*/\1/')
                if echo "$line" | grep -q spare ; then
                    spares="${spares}${pdname},"
                else
                    drives="${drives}${pdname},"
                fi
            fi
            ;;
        *unassigned*)
            break
            ;;
    esac
done < $TMP_DIR/hpraid-config.tmp
write_logicaldrive

for controller in "${controllers[@]}" ; do
    echo "smartarray $controller" >> $DISKLAYOUT_FILE
done
