# Collect HP Smartarray information

if ! type hpacucli &>/dev/null ; then
    return 0
fi

# Add hpacucli to the rescue image
PROGS=( "${PROGS[@]}" hpacucli )
eval $(grep ON_DIR= $(type -p hpacucli))
COPY_AS_IS=( "${COPY_AS_IS[@]}" "$HPACUCLI_BIN_INSTALLATION_DIR" )

LogPrint "Saving HP SmartArray configuration."

### In case we have a controller problem, the hpacucli output may not reflect
### the actual configuration of the system, and hence the layout output could
### be incorrect ! Fail this is the case !
hpacucli ctrl all show detail > $TMP_DIR/hpraid-detail.tmp
grep 'Controller Status:' $TMP_DIR/hpraid-detail.tmp | grep -v 'Controller Status: OK'
if (( $? != 1 )); then
    Error "One or more HP SmartArray controllers have errors, fix this first !"
fi

hpacucli ctrl all show config > $TMP_DIR/hpraid-config.tmp

write_logicaldrive() {
    if [ -n "$drives" ] ; then
        echo "logicaldrive $devname $slotnr|$arrayname|$ldname raid=$raidlevel drives=$drives spares=$spares sectors=$sectors stripesize=$stripesize" >> $DISKLAYOUT_FILE
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
            echo "smartarray $nextslotnr" >> $DISKLAYOUT_FILE
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
            drivedetails=$(echo "$line" | sed -r 's/.*logicaldrive ([^ ]+) .*RAID ([^ ]+),.*/\1 \2/')
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
