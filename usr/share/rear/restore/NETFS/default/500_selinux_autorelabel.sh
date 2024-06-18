# In some case we re-defined BACKUP_SELINUX_DISABLE=0 in our local.conf file as we want to
# honor SELinux settings during backup (and restore).
# However, and this is the main reason of this script, the 'tar' or 'rsync' programs are not
# capable of correctly handling SELinux labels. This was testing during the the prep phase, e.g. see
# usr/share/rear/prep/RSYNC/GNU/Linux/200_selinux_in_use.sh script.
# When proper SELinux handling is not possible above mentioned script will create the file
# $opath/selinux.autorelabel. Therefore, in this script we check if this file exist and when the
# answer is yes force auto relabeling the files after the reboot to have a correct SELinux labeled system.

# If selinux was turned off for the backup we have to label the
local scheme="$( url_scheme "$BACKUP_URL" )"
local path="$( url_path "$BACKUP_URL" )"
local opath="$( backup_path "$scheme" "$path" )"

if test -f "$opath/selinux.autorelabel" ; then
    touch $TARGET_FS_ROOT/.autorelabel
    Log "Created /.autorelabel file : after reboot SELinux will relabel all files"
fi

