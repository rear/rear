# 450_restore_via_gui.sh
# If the automatic restore failes give the user the option to execute a restore via GUI

[ ! -f $TMP_DIR/DP_GUI_RESTORE ] && return   # restore was OK - skip this option

Log "Request for a manual restore via the GUI"

LogUserOutput "
**********************************************************************
* The Data Protector client is available on the network. Restore a
* backup from the Data Protector GUI. Make sure you select 'Overwrite'
* from Destination tab and $TARGET_FS_ROOT as destination.
*
* When the restore is complete press ANY key to continue!
**********************************************************************
"
# Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
# because 'read' outputs non-error stuff also to STDERR (e.g. its prompt):
read answer 0<&6 1>&7 2>&8
