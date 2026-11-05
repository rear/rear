# 550_restore_saved_layout.sh

# With NBU_RESTORE_SAVED_LAYOUT enabled, fetch this client's own disk layout
# (disklayout.conf and layout/config/*, saved by 'rear savelayout' and
# included in the regular file backup) from the NetBackup backup, and use it
# instead of the layout baked into a generic recovery image. Runs after the
# certificate enrollment and after the source client and point in time were
# chosen, so 'bprestore' works. Runs before layout/prepare reads the layout.

is_true "$NBU_RESTORE_SAVED_LAYOUT" || return 0

local nbu_bprestore=/usr/openv/netbackup/bin/bprestore
local nbu_bplist=/usr/openv/netbackup/bin/bplist
local nbu_saved_dir="$TMP_DIR/nbu_saved_layout"
local nbu_layout_dir="$VAR_DIR/layout"
local bprestore_args rc

test -n "$NBU_ENDTIME" || Error "No NetBackup catalog entry available, cannot restore the saved disk layout of $NBU_CLIENT_SOURCE."
test -n "$NBU_STARTTIME" || Error "No full NetBackup backup start time available, cannot restore the saved disk layout of $NBU_CLIENT_SOURCE."

rm -rf $nbu_saved_dir
mkdir -p $nbu_saved_dir || Error "Cannot create $nbu_saved_dir."

# The saved layout must exist in the selected backup. 'bplist' returns 0 only
# for an existing path. No TIR flag, it does not work for single files.
"$nbu_bplist" -t 0 -s ${NBU_STARTTIME} -e ${NBU_ENDTIME} -C "$NBU_CLIENT_SOURCE" "$nbu_layout_dir/disklayout.conf" &>/dev/null || Error "$nbu_layout_dir/disklayout.conf is not in the NetBackup backup of $NBU_CLIENT_SOURCE ($NBU_STARTTIME - $NBU_ENDTIME). Run 'rear savelayout' on the client before the backup, or set NBU_RESTORE_SAVED_LAYOUT=false."

# Only the saved layout files, renamed into a scratch directory so the
# layout of this image stays untouched if the restore fails.
echo "$nbu_layout_dir/disklayout.conf" > $TMP_DIR/nbu_layout_list || Error "Cannot write $TMP_DIR/nbu_layout_list."
echo "change $nbu_layout_dir/disklayout.conf to $nbu_saved_dir/disklayout.conf" > $TMP_DIR/nbu_layout_change_file || Error "Cannot write $TMP_DIR/nbu_layout_change_file."
if "$nbu_bplist" -t 0 -s ${NBU_STARTTIME} -e ${NBU_ENDTIME} -C "$NBU_CLIENT_SOURCE" -R 0 "$nbu_layout_dir/config" &>/dev/null ; then
    echo "$nbu_layout_dir/config" >> $TMP_DIR/nbu_layout_list
    echo "change $nbu_layout_dir/config to $nbu_saved_dir/config" >> $TMP_DIR/nbu_layout_change_file
fi

bprestore_args="-B -H -L /usr/openv/netbackup/logs/user_ops/root/logs/bprestore_layout.log -R $TMP_DIR/nbu_layout_change_file -t 0 -w 0 -s ${NBU_STARTTIME} -e ${NBU_ENDTIME} -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/nbu_layout_list"

UserOutput ""
UserOutput "Restoring the saved disk layout of $NBU_CLIENT_SOURCE from the NetBackup backup:"
LogPrint "$nbu_bprestore $bprestore_args"
"$nbu_bprestore" $bprestore_args
rc=$?
test $rc -eq 0 || Error "'bprestore' of the saved disk layout failed (return code = $rc). Check the restore job's log on the NetBackup Primary server. Set NBU_RESTORE_SAVED_LAYOUT=false to use the disk layout of this recovery image instead."

test -s $nbu_saved_dir/disklayout.conf || Error "'bprestore' reported success but $nbu_layout_dir/disklayout.conf is missing in the backup of $NBU_CLIENT_SOURCE. Run 'rear savelayout' on the client before the backup, or set NBU_RESTORE_SAVED_LAYOUT=false."

# Replace the layout of the generic image by the saved one.
cp -a $nbu_saved_dir/disklayout.conf $nbu_layout_dir/disklayout.conf || Error "Cannot copy the saved disklayout.conf to $nbu_layout_dir."
if test -d $nbu_saved_dir/config ; then
    mkdir -p $nbu_layout_dir/config
    cp -a $nbu_saved_dir/config/. $nbu_layout_dir/config/ || Error "Cannot copy the saved layout/config files to $nbu_layout_dir/config."
fi
UserOutput "Using the disk layout saved from $NBU_CLIENT_SOURCE ($NBU_ENDTIME) for the recovery."
