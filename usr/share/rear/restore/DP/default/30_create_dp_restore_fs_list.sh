# 30_create_dp_restore_fs_list.sh
# Purpose: Generate a file system list of objects to restore

# $ /opt/omni/bin/omnidb -filesystem | grep $(hostname)
# test.internal.it3.be:/ '/'                                      FileSystem

[ -f /tmp/DP_GUI_RESTORE ] && return # GUI restore explicetely requested

/opt/omni/bin/omnidb -session $(cat /tmp/dp_recovery_session) | cut -d"'" -f -2 > /tmp/list_of_fs_objects
[ -s /tmp/list_of_fs_objects ]
StopIfError "Data Protector did not find any file system objects for $(hostname)"

# check if we need to exclude a file system - exclude fs list =  $VAR_DIR/recovery/exclude_mountpoints
if [ -f $VAR_DIR/recovery/exclude_mountpoints ]; then
	HostObj=`tail -n 1 /tmp/list_of_fs_objects | cut -d: -f 1`
	Log "Info: $VAR_DIR/recovery/exclude_mountpoints found. Remove from restore file system list."
	sed -e 's;^/;'${HostObj}':/;' $VAR_DIR/recovery/exclude_mountpoints >/tmp/exclude_mountpoints
	# /tmp/exclude_mountpointscontains e.g. test.internal.it3.be:/usr/sap
	# use join to remove excluded file systems to restore
	join -v 1 /tmp/list_of_fs_objects /tmp/exclude_mountpoints
fi
