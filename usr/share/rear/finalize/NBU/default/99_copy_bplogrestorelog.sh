# 99_copy_bprestorelog.sh
# copy the logfile to the recovered system, at least the part that has been written till now.

mkdir -p $TARGET_FS_ROOT/root
cp -f $TMP_DIR/bplog.restore* $TARGET_FS_ROOT/root/
