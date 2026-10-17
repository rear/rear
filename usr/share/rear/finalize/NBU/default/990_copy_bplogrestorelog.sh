# 990_copy_bplogrestorelog.sh

# Copy the 'bprestore' log to the recovered system root home
# directory, so the operator has it for reference after reboot.

mkdir -p $v "$TARGET_FS_ROOT/$ROOT_HOME_DIR"
LogPrintIfError "Failed to create $TARGET_FS_ROOT/$ROOT_HOME_DIR."
cp -f $v /usr/openv/netbackup/logs/user_ops/root/logs/bprestore.log "$TARGET_FS_ROOT/$ROOT_HOME_DIR/"
LogPrintIfError "Failed to copy /usr/openv/netbackup/logs/user_ops/root/logs/bprestore.log to $TARGET_FS_ROOT/$ROOT_HOME_DIR."
