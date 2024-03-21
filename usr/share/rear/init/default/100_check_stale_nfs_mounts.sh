# 100_check_stale_nfs_mounts.sh
# Purpose is to have a simple test if we have stale NFS mount points which
# could lead to a hangind ReaR session.
# In case there is a stale NFS present we bail out with an error to get it fixed before
# running ReaR again.
# See issue https://github.com/rear/rear/issues/3109
# To make the code more robust we take care of spaces and \ in the mount point naming.
### example mount point /mnt/!@#$%^&**()_-=+{}|\
# + read -r exported_fs mount_point junk
#++ grep -i '[[:blank:]]nfs' /proc/mounts
#++ sed -e 's/\\040/ /g' -e 's/\\134/\\/g'
#+ mntpt='/mnt/!@#$%^&**()_-=+{}|\'
#+ timeout 5 df '/mnt/!@#$%^&**()_-=+{}|\'
#
# or
#
#+ read -r exported_fs mount_point junk
#++ grep -i '[[:blank:]]nfs' /proc/mounts
#++ sed -e 's/\\040/ /g' -e 's/\\134/\\/g'
#+ mntpt='/mnt/something else with xXx going on!'
#+ timeout 5 df '/mnt/something else with xXx is going on!'

while read -r exported_fs mount_point junk ;
do
    mntpt="$(sed -e 's/\\040/ /g' -e 's/\\134/\\/g' <<< "$mount_point")"
    timeout 5 df "$mntpt" >/dev/null || Error "Stale NFS mount point $mount_point detected - please fix it first!"
done < <(grep -i "[[:blank:]]nfs" /proc/mounts)
