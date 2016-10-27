# Code to recreate HP SmartArray controllers.

define_HPSSACLI  # Call function to find proper Smart Storage Administrator CLI command - define $HPSSACLI var

create_smartarray() {
    local sa slotnr junk
    read sa slotnr junk < <(grep "^smartarray ${1#sma:} " "$LAYOUT_FILE")
    cat <<EOF >>"$LAYOUT_CODE"
LogPrint "Clearing HP SmartArray controller $slotnr"
if ! $HPSSACLI ctrl slot=$slotnr delete forced >&8; then
    Log "Failed to clear HP SmartArray controller $slotnr, this is not necessarily fatal."
fi
EOF
}

create_logicaldrive() {
    local ld disk path options
    read ld disk path options < <(grep "^logicaldrive ${1#ld:} " "$LAYOUT_FILE")

    local slotnr=${path%%|*}
    local arrayname=${path%|*}
    arrayname=${arrayname#*|}

    local raid="" drives="" spares="" sectors="" stripesize=""
    local option key value
    for option in $options ; do
        key=${option%=*}
        value=${option#*=}

        if [ -z "$value" ] ; then
            continue
        fi

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
    echo "LogPrint \"Recreating HP SmartArray controller $slotnr|$arrayname\"" >> "$LAYOUT_CODE"
    echo "$HPSSACLI ctrl slot=$slotnr create type=ld ${drives}${raid}${sectors}${stripesize}" >> "$LAYOUT_CODE"
    if [ -n "$spares" ] ; then
        echo "$HPSSACLI ctrl slot=$slotnr array $arrayname add${spares}" >> "$LAYOUT_CODE"
    fi
cat >> "$LAYOUT_CODE" <<EOF
LogPrint "Configuration restored successfully, reloading CCISS driver..."
sleep 2
rmmod cciss
sleep 2
modprobe cciss
sleep 2

# Make sure device nodes are visible (eg. in RHEL4)
my_udevtrigger
my_udevsettle
EOF
    echo "" >> "$LAYOUT_CODE"
}
