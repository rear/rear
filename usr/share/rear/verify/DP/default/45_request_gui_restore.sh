##############################################################################
#
# Press [gG] to failback to GUI restore

#set -e
rm -f /tmp/DP_GUI_RESTORE # ensure the flag DP GUI restore request does not exists

unset REPLY
read -t 30 -r -n 1 -p "press \"G\" to failback to DP GUI restore [30sec]: " 2>&1

if test "${REPLY}" = "g" -o "${REPLY}" = "G"; then
    Log "DP GUI restore requested"
    > /tmp/DP_GUI_RESTORE
fi
