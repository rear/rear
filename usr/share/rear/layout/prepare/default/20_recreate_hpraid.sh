# Ask to recreate HP raid before the actual restoration takes place.

if ! grep -q '^cciss ' /proc/modules; then
    return
fi

ORIG_LAYOUT_CODE=$LAYOUT_CODE

LAYOUT_CODE=$VAR_DIR/layout/hpraid.sh

cat <<EOF > $LAYOUT_CODE
set -e

# Unload CCISS module to make sure nothing is using it
rmmod cciss
StopIfError "CCISS failed to unload, something is still using it !"

modprobe cciss
sleep 2
EOF

restored_controllers=()

# Start by clearing all controllers
while read -u 3 type name junk ; do
    read -p "To recreate HP SmartArray controller $name, type exactly YES: " -t 20 2>&1
    if [ "$REPLY" = "YES" ] ; then
        create_device "$name" "smartarray"
        restored_controllers=( "${restored_controllers[@]}" $name )
    fi
done 3< <(grep "^smartarray " $LAYOUT_FILE)

# Now, recreate all logical drives whose controller was cleared.
while read type name remainder junk ; do
    ctrl=$(echo "$remainder" | cut -d " " -f1 | cut -d "|" -f1)
    if IsInArray "$ctrl" "${restored_controllers[@]}" ; then
        create_device "$name" "logicaldrive"
    fi
done < <(grep "^logicaldrive " $LAYOUT_FILE)

echo "set +e" >> $LAYOUT_CODE

if [ ${#restored_controllers} -ne 0 ] ; then
    (
    . $LAYOUT_CODE
    )
    BugIfError "Could not configure the HP SmartArray controllers. Please see $LOGFILE for details."
fi

LAYOUT_CODE=$ORIG_LAYOUT_CODE
