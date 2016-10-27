##############################################################################
#
# Press [gG] to failback to GUI restore

#set -e
rm -f $TMP_DIR/DP_GUI_RESTORE # ensure the flag DP GUI restore request does not exists

unset REPLY
read -t $WAIT_SECS -r -n 1 -p "press \"G\" to failback to DP GUI restore [$WAIT_SECS secs]: " 2>&1

if test "${REPLY}" = "g" -o "${REPLY}" = "G"; then
    Log "DP GUI restore requested"
    > $TMP_DIR/DP_GUI_RESTORE
fi
