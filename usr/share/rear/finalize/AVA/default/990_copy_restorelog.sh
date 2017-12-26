# 99_copy_bprestorelog.sh
# copy the logfile to the recovered system, at least the part that has been written till now.
cp -f /tmp/avagent.log /mnt/local/opt/avamar/var/avagent.log
