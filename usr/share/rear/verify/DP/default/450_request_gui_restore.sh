##############################################################################
#
# Press [gG] to fall back to GUI restore

#set -e

# ensure the flag DP GUI restore request does not exists
rm -f $TMP_DIR/DP_GUI_RESTORE

unset REPLY
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
read -t $WAIT_SECS -r -n 1 -p "press 'G' to fall back to Data Protector GUI-based restore [$WAIT_SECS secs]: " 0<&6 1>&7 2>&8

if test "$REPLY" = "g" -o "$REPLY" = "G" ; then
    Log "Data Protector GUI restore requested"
    > $TMP_DIR/DP_GUI_RESTORE
fi
