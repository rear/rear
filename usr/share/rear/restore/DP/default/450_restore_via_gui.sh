# 450_restore_via_gui.sh
# id the automatic restore failed give the end-user the option to execute a retsore via GUI

[ ! -f $TMP_DIR/DP_GUI_RESTORE ] && return   # restore was OK - skip this option

Log "Request for a manual restore via the GUI"

LogUserOutput "
**********************************************************************
**  Please try to push the backups of the latest session from DP GUI
**  Make sure you select \"overwrite\" (destination tab) and make the
**  new destination $TARGET_FS_ROOT.
**  When the restore is complete press ANY key to continue!
**********************************************************************
"
# Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
# because 'read' outputs non-error stuff also to STDERR (e.g. its prompt):
read answer 0<&6 1>&7 2>&8

