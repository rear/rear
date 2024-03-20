# 100_check_stale_nfs_mounts.sh
# Purpose is to have a simple test if we have stale NFS mount points which
# could lead to a hangind ReaR session.
# In case there is a stale NFS present we bail out with an error to get it fixed before
# running ReaR again.
# See issue https://github.com/rear/rear/issues/3109
while read exported_fs mount_point junk ;
do
    timeout 5 df $mount_point >/dev/null || Error "Stale NFS mount point $mount_point detected - please fix it first!"
done < <(cat /proc/mounts | grep -i "[[:blank:]]nfs")
