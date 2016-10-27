# Ask to recreate HP raid before the actual restoration takes place.

if ! grep -q '^cciss ' /proc/modules; then
    return
fi

ORIG_LAYOUT_CODE="$LAYOUT_CODE"

LAYOUT_CODE=$VAR_DIR/layout/hpraid.sh

cat <<EOF >$LAYOUT_CODE
set -e

# Unload CCISS module to make sure nothing is using it
rmmod cciss || Error "CCISS failed to unload, something is still using it !"

modprobe cciss
sleep 2
EOF

restored_controllers=()

# Start by clearing all controllers
while read -u 3 type name junk ; do
    read -p "To recreate HP SmartArray controller $name, type exactly YES: " 2>&1
    if [ "$REPLY" = "YES" ] ; then
        create_device "$name" "smartarray"
        restored_controllers=( "${restored_controllers[@]}" $name )
    fi
done 3< <(grep "^smartarray " "$LAYOUT_FILE")

# Now, recreate all logical drives whose controller was cleared.
while read type name remainder junk ; do
    ctrl=$(echo "$remainder" | cut -d " " -f1 | cut -d "|" -f1)
    if IsInArray "$ctrl" "${restored_controllers[@]}" ; then
        create_device "$name" "logicaldrive"
    fi
done < <(grep "^logicaldrive " "$LAYOUT_FILE")

### engage scsi can fail in certain cases
cat <<'EOF' >>"$LAYOUT_CODE"
set +e

# make the CCISS tape device visible
for host in /proc/driver/cciss/cciss?; do
    Log "Engage SCSI on host $host"
    echo engage scsi >$host
done

sleep 2
EOF

if [ ${#restored_controllers} -ne 0 ] ; then
    define_HPSSACLI  # call function to find proper Smart Storage Administrator CLI command - define $HPSSACLI var
    RESTORE_OK=
    while [[ -z "$RESTORE_OK" ]]; do
        (
            . "$LAYOUT_CODE"
        )

        if (( $? == 0 )); then
            RESTORE_OK=y
        else
            LogPrint "Could not configure an HP SmartArray controllers."
            Print ""

            # TODO: Provide a skip option (needs torough consideration)
            choices=(
                "View Relax-and-Recover log"
                "Go to Relax-and-Recover shell"
#                "Edit disk layout (disklayout.conf)"
                "Edit restore script (hpraid.sh)"
                "Restart restore script"
                "Abort Relax-and-Recover"
            )

            timestamp=$(stat --format="%Y" "$LAYOUT_CODE")
            select choice in "${choices[@]}"; do
                timestamp=$(stat --format="%Y" "$LAYOUT_FILE")
                case "$REPLY" in
                    (1) less "$LOGFILE";;
                    (2) rear_shell "" "$HPSSACLI ctrl all show detail
$HPSSACLI ctrl all show config detail
$HPSSACLI ctrl all show config
";;
#                    (3) vi $LAYOUT_FILE;;
                    (3) vi "$LAYOUT_CODE";;
                    (4) if (( $timestamp < $(stat --format="%Y" "$LAYOUT_CODE") )); then
                            break
                        else
                            Print "Script $LAYOUT_CODE has not been changed, restarting has no impact."
                        fi
                        ;;
                    (5) break;;
                esac

                # Reprint menu options when returning from less, shell or vi
                Print ""
                for (( i=1; i <= ${#choices[@]}; i++ )); do
                    Print "$i) ${choices[$i-1]}"
                done
            done 2>&1

            Log "User selected: $REPLY) ${choices[$REPLY-1]}"

            if (( REPLY == ${#choices[@]} )); then
                abort_recreate

                Error "There was an error restoring the HP SmartArray drives. See $LOGFILE for details."
            fi
        fi
    done
fi

LAYOUT_CODE="$ORIG_LAYOUT_CODE"
