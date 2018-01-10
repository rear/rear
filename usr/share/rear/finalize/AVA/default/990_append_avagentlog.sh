# 990_append_avagentlog.sh
# append the logfile to the recovered system, at least the part that has been written till now.
cat /var/avamar/avagent.log >> $TARGET_FS_ROOT/var/avamar/avagent.log
