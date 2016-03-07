
# If selinux was turned off for the backup we have to label the
local scheme=$( url_scheme $BACKUP_URL )
local path=$( url_path $BACKUP_URL )
local opath=$( backup_path $scheme $path )

if test -f "$opath/selinux.autorelabel" ; then
    touch $TARGET_FS_ROOT/.autorelabel
    Log "Created /.autorelabel file : after reboot SELinux will relabel all files"
fi

