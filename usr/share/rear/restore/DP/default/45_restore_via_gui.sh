# 45_restore_via_gui.sh
# id the automatic restore failed give the end-user the option to execute a retsore via GUI

[ ! -f $TMP_DIR/DP_GUI_RESTORE ] && return   # restore was OK - skip this option

Log "Request for a manual restore via the GUI"

echo "
***************************************************************************
**  Please try to push the backups of the latest session from DP GUI     **
**  Make sure you select \"overwrite\" (destination tab) and make the      **
**  new destination /mnt/local.                                          **
**  When the restore is complete press ANY key to continue!              **
***************************************************************************
"
   read answer
