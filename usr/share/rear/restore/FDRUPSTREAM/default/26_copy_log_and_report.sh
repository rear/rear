# upstream.log and upstream.rpt on the ReaR system contains valuable 
# information about the disaster recovery, so we archive *.log and *.rpt
# to the restored system.

EXTENSION="restore_$( date +%F_%T )"

echo
for file in $FDRUPSTREAM_INSTALL_PATH/*.log $FDRUPSTREAM_INSTALL_PATH/*.rpt; do
    LogPrint "Archiving "$( basename "$file" )" to the restored system as:"
    LogPrint "  $( basename "$file" ).$EXTENSION"
    cp "$file" "$TARGET_FS_ROOT/$file.$EXTENSION"
    LogPrintIfError "Error archiving $file.  Before rebooting, be sure to copy logs and/or reports from $FDRUPSTREAM_INSTALL_PATH into the $TARGET_FS_ROOT file tree."
    echo
done
