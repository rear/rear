# 40_restore_with_nbu.sh
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

LogPrint "NetBackup: restoring / into /mnt/local"

# $TMP_DIR/restore_fs_list was made by 30_create_nbu_restore_fs_list.sh

echo "change / to /mnt/local" > $TMP_DIR/nbu_change_file

if [ ${#NBU_ENDTIME[@]} -gt 0 ]
then
   edate="${NBU_ENDTIME[@]}"
   ARGS="-B -H -L $TMP_DIR/bplog.restore -8 -R $TMP_DIR/nbu_change_file -t 0 -w 0 -e ${edate} -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/restore_fs_list"
else
   ARGS="-B -H -L $TMP_DIR/bplog.restore -8 -R $TMP_DIR/nbu_change_file -t 0 -w 0 -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/restore_fs_list"
fi

LogPrint "RUN: /usr/openv/netbackup/bin/bprestore ${ARGS}"
LogPrint "Restore progress: see $TMP_DIR/bplog.restore"
LANG=C /usr/openv/netbackup/bin/bprestore ${ARGS}
if (( $? > 1 )); then
    Error "bprestore failed (return code = $?)"
fi
