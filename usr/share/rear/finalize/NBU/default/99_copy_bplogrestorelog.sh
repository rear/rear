# 99_copy_bprestorelog.sh
# copy the logfile to the recovered system, at least the part that has been written till now.

mkdir -p /mnt/local/root
cp -f /tmp/bplog.restore.* /mnt/local/root/
