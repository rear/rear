# 400_save_mountpoint_details.sh
# Purpose of this script is to save the ownership and permissions of the mount points in a file
# That file will be read during recovery time to recreate missing directories and set up the proper
# permissions again (for the moment it is scattered across different flows)
# Script restore/default/90_create_missing_directories.sh will recreate the missing dirs (all other
# script may be deleted)

: > "$VAR_DIR/recovery/mountpoint_permissions"
# drwxr-xr-x.  20 root root  4096 Nov  2 07:44 /
while read junk junk userid groupid junk junk junk junk dir
do
    [[ $dir = / ]] && continue
    echo ${dir#/*} $(stat -c %a $dir) $userid $groupid >> "$VAR_DIR/recovery/mountpoint_permissions"
done < <(ls -ld $(mount | grep -vE '(cgroup|fuse|nfsd|/sys/|REAR-000)' | awk '{print $3}'))

# output looks like boot 755 root root
