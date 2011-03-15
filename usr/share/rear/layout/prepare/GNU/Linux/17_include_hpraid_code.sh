# Code to recreate HP SmartArray controllers

create_smartarray() {
    read sa slotnr junk < $1
    echo "LogPrint \"Clearing HP SmartArray controller $slotnr\"" >> $LAYOUT_CODE
    echo "hpacucli ctrl slot=$slotnr delete forced" >> $LAYOUT_CODE
}

create_logicaldrive() {
    read ld disk path options < $1
    
    slotnr=${path%%|*}
    arrayname=${path%|*}
    arrayname=${arrayname#*|}
    
    raid=""
    drives=""
    spares=""
    sectors=""
    stripesize=""
    for option in $options ; do
        key=${option%=*}
        value=${option#*=}
        
        case $key in
            raid)
                raid=" raid=$value"
                ;;
            drives)
                drives=" drives=${value%,}"
                ;;
            spares)
                if [ -n "$value" ] ; then
                    spares=" spares=${value%,}"
                fi
                ;;
            sectors)
                sectors=" sectors=$value"
                ;;
            stripesize)
                stripesize=" stripesize=$value"
        esac
    done
    echo "LogPrint \"Recreating HP SmartArray controller $slotnr|$arrayname\"" >> $LAYOUT_CODE
    echo "hpacucli ctrl slot=$slotnr create type=ld ${drives}${raid}${sectors}${stripesize}" >> $LAYOUT_CODE
    if [ -n "$spares" ] ; then
        echo "hpacucli ctrl slot=$slotnr array $arrayname add${spares}" >> $LAYOUT_CODE
    fi
cat >> $LAYOUT_CODE <<EOF
ProgressStart "Configuration restored successfully, reloading CCISS driver..."
sleep 1 ; ProgressStep ; sleep 1
rmmod cciss
sleep 1 ; ProgressStep ; sleep 1
modprobe cciss
sleep 1 ; ProgressStep ; sleep 1
ProgressStop
EOF
    echo "" >> $LAYOUT_CODE
}