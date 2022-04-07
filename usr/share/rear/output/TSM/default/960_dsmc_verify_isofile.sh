# 960_dsmc_verify_isofile.sh

is_true $TSM_RM_ISOFILE || return 0

Log "Verify if the ISO file '$TSM_RESULT_FILE_PATH/$ISO_PREFIX.iso' was archived correctly with dsmc"
if [[ -z "$TSM_ARCHIVE_MGMT_CLASS" ]]; then
    LC_ALL=${LANG_RECOVER} dsmc q backup "$TSM_RESULT_FILE_PATH/$ISO_PREFIX.iso" >/dev/null
else
    LC_ALL=${LANG_RECOVER} dsmc q archive "$TSM_RESULT_FILE_PATH/$ISO_PREFIX.iso" >/dev/null
fi
if [[ $? -eq 0 ]]; then
    Log "Removing $ISO_DIR/$ISO_PREFIX.iso to preserve space"
    if rm $v -f $ISO_DIR/$ISO_PREFIX.iso ; then
        LogPrint "The only remaining copy of the ISO file is under TSM:$TSM_RESULT_FILE_PATH/$ISO_PREFIX.iso"
        Log "To preserve space also removing the TSM_RESULT_FILES ${TSM_RESULT_FILES[*]}"
        rm $v -f "${TSM_RESULT_FILES[@]}"
    else
        Log "Could not remove $ISO_DIR/$ISO_PREFIX.iso so the local files are kept"
    fi
else
   LogPrint "TSM did not confirm that the ISO file was stored properly so the local files are kept"
fi

