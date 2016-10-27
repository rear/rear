# 96_dsmc_verify_isofile.sh
if [[ ! "$TSM_RM_ISOFILE" =~ [yY1] ]] ; then
    return
fi

Log "Verify if the files '$TSM_RESULT_FILE_PATH/$ISO_PREFIX.iso' were archived correctly with dsmc"
if [[ -z "$TSM_ARCHIVE_MGMT_CLASS" ]]; then
    LC_ALL=${LANG_RECOVER} dsmc q backup "$TSM_RESULT_FILE_PATH/$ISO_PREFIX.iso" >&8
else
    LC_ALL=${LANG_RECOVER} dsmc q archive "$TSM_RESULT_FILE_PATH/$ISO_PREFIX.iso" >&8
fi
if [[ $? -eq 0 ]]; then
    Log "Removing the '${TSM_RESULT_FILES[@]}' files to preserve space"
    rm $v -f ${TSM_RESULT_FILES[@]} >&8
    Log "Remove the $ISO_DIR/$ISO_PREFIX.iso to preserve space"
    rm $v -f $ISO_DIR/$ISO_PREFIX.iso >&8
    LogPrint "The only remaining copy of the ISO file is under TSM:$TSM_RESULT_FILE_PATH/$ISO_PREFIX.iso"
else
   LogPrint "TSM did not confirm correctly if the ISO file was stored properly - not remove local ISO files"
fi

