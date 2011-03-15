# Ask to recreate HP raid before the actual restoration takes place.

ORIG_LAYOUT_CODE=$LAYOUT_CODE

LAYOUT_CODE=$VAR_DIR/layout/hpraid.sh
: > $LAYOUT_CODE
echo "set -e" >> $LAYOUT_CODE

restored_controllers=()

while read -u 3 type remainder ; do
    case $type in
        smartarray)
            name=$(echo "$remainder" | cut -d " " -f "1")
            read -p "To recreate HP SmartArray controller $name, type exactly YES: " -t 20 2>&1
            if [ "$REPLY" = "YES" ] ; then
                create_device "$name" "smartarray"
                restored_controllers=( "${restored_controllers[@]}" $name )
            fi
            ;;
        logicaldrive)
            name=$(echo "$remainder" | cut -d " " -f "1")
            ctrl=$(echo "$remainder" | cut -d " " -f "2" | cut -d "|" -f "1")
            if IsInArray "$ctrl" "${restored_controllers[@]}" ; then
                create_device "$name" "logicaldrive"
            fi
            ;;
    esac
done 3< <(grep -E "smartarray|logicaldrive" $LAYOUT_FILE)

echo "set +e" >> $LAYOUT_CODE

(
. $LAYOUT_CODE
)

if [ $? -ne 0 ] ; then
    Error "Could not configure the HP SmartArray controllers. Please see $LOGFILE for details."
fi

LAYOUT_CODE=$ORIG_LAYOUT_CODE
