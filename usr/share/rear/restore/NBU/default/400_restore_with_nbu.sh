# 400_restore_with_nbu.sh
# restore files with NBU
#-----<--------->-------
export starposition=1
star ()
{
    set -- '/' '-' '\' '|';
    test $starposition -gt 4 -o $starposition -lt 1 && starposition=1;
    echo -n "${!starposition}";
    echo -en "\r";
    let starposition++
    #sleep 0.1
}
#-----<--------->-------

LogPrint "NetBackup: restoring / into $TARGET_FS_ROOT"

# $TMP_DIR/restore_fs_list was made by 30_create_nbu_restore_fs_list.sh

echo "change / to $TARGET_FS_ROOT" > $TMP_DIR/nbu_change_file

# Do not use ARGS here because that is readonly in the rear main script:
if [ ${#NBU_ENDTIME[@]} -gt 0 ]
then
   edate="${NBU_ENDTIME[@]}"
   bprestore_args="-B -H -L $TMP_DIR/bplog.restore -8 -R $TMP_DIR/nbu_change_file -t 0 -w 0 -e ${edate} -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/restore_fs_list"
else
   bprestore_args="-B -H -L $TMP_DIR/bplog.restore -8 -R $TMP_DIR/nbu_change_file -t 0 -w 0 -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/restore_fs_list"
fi

LogPrint "RUN: /usr/openv/netbackup/bin/bprestore $bprestore_args"
LogPrint "Restore progress: see $TMP_DIR/bplog.restore"
LANG=C /usr/openv/netbackup/bin/bprestore $bprestore_args
if (( $? > 1 )); then
    Error "bprestore failed (return code = $?)"
fi
