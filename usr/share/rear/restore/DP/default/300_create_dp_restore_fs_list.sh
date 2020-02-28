# 300_create_dp_restore_fs_list.sh
# Purpose: Generate a file system list of objects to restore

# $ /opt/omni/bin/omnidb -filesystem | grep $(hostname)
# test.internal.it3.be:/ '/'                                      FileSystem

[ -f $TMP_DIR/DP_GUI_RESTORE ] && return # GUI restore explicetely requested

OMNIDB=/opt/omni/bin/omnidb

${OMNIDB} -session $(cat $TMP_DIR/dp_recovery_session) | grep `cat $TMP_DIR/dp_recovery_host` | cut -d"'" -f -2 > $TMP_DIR/list_of_fs_objects
[ -s $TMP_DIR/list_of_fs_objects ]
StopIfError "Data Protector did not find any file system objects for $(hostname)"

# check if we need to exclude a file system - exclude fs list =  $VAR_DIR/recovery/exclude_mountpoints
if [ -f $VAR_DIR/recovery/exclude_mountpoints ]; then
	HostObj=`tail -n 1 $TMP_DIR/list_of_fs_objects | cut -d: -f 1`
	Log "Info: $VAR_DIR/recovery/exclude_mountpoints found. Remove from restore file system list."
	sed -e 's;^/;'${HostObj}':/;' $VAR_DIR/recovery/exclude_mountpoints > $TMP_DIR/exclude_mountpoints
	# $TMP_DIR/exclude_mountpoints contains e.g. test.internal.it3.be:/usr/sap
	# use join to remove excluded file systems to restore
	join -v 1 $TMP_DIR/list_of_fs_objects $TMP_DIR/exclude_mountpoints
fi
