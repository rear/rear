# When the backup method does not support SELinux context preservation,
# backup/*/GNU/Linux/620_force_autorelabel.sh creates a selinux.autorelabel file
# in the backup location to signal that SELinux relabeling is needed after restore.
#
# This happens when:
# - tar supports neither --selinux nor --xattrs-include options
# - rsync does not support --xattrs option
# - custom BACKUP_PROG does not support SELinux context preservation
#
# If this file exists, create /.autorelabel in the restored system to trigger
# SELinux relabeling on the next boot.
local scheme="$( url_scheme "$BACKUP_URL" )"
local path="$( url_path "$BACKUP_URL" )"
local opath="$( backup_path "$scheme" "$path" )"

if test -f "$opath/selinux.autorelabel" ; then
    touch $TARGET_FS_ROOT/.autorelabel
    Log "Created /.autorelabel file : after reboot SELinux will relabel all files"
fi

