# 300_create_nbu_restore_fs_list.sh
##################################

# Part 1: create the restore file system list file
[ -f $VAR_DIR/recovery/mountpoint_device ]
StopIfError "Cannot start restore as $VAR_DIR/recovery/mountpoint_device is missing"
cat $VAR_DIR/recovery/mountpoint_device | awk '{print $1}' | sort -u > $TMP_DIR/restore_fs_list

# Part 2: check if $VAR_DIR/recovery/exclude_mountpoints exist
# $VAR_DIR/recovery/exclude_mountpoints is a sorted file with one FS per line to exclude
if [ -f $VAR_DIR/recovery/exclude_mountpoints ]; then
	# file was created only when a FS was detected to exclude
	Log "Info: $VAR_DIR/recovery/exclude_mountpoints found. Remove from restore file system list."
	grep -v -f $VAR_DIR/recovery/exclude_mountpoints $TMP_DIR/restore_fs_list > $TMP_DIR/restore_fs_list.new
	mv -f $TMP_DIR/restore_fs_list.new $TMP_DIR/restore_fs_list
fi

# Part 3: prepend filepathlen before each filepath in file $TMP_DIR/nbu_backuplist (for bprestore)
#cat $TMP_DIR/nbu_backuplist | awk '{print length, $0}' > $TMP_DIR/nbu_inputfile

# Part 4: Add excluded filesystems to the listfile used in the -f option of the bprecover command
if grep -q "^/$" $TMP_DIR/restore_fs_list
then
   echo "!$TARGET_FS_ROOT" >> $TMP_DIR/restore_fs_list
fi
if [ ${#EXCLUDE_MOUNTPOINTS[@]} -gt 0 ]
then
    for FS in "${EXCLUDE_MOUNTPOINTS[@]}"
    do
        echo "${FS}/" >> $TMP_DIR/restore_fs_list
        echo "!${FS}/*" >> $TMP_DIR/restore_fs_list
    done
fi
