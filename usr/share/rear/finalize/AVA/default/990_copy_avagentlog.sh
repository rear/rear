# 99_copy_avagentlog.sh
# copy the logfile to the recovered system, at least the part that has been written till now.
cp -f /tmp/avagent.log $TARGET_FS_ROOT/opt/avamar/var/avagent.log
