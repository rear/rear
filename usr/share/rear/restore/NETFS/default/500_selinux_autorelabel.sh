# In some case we re-defined BACKUP_SELINUX_DISABLE=0 in our local.conf file as we want to
# honor SELinux settings during backup (and restore).
# However, and this is the main reason of this script, the 'tar' or 'rsync' programs are not
# capable of correctly handling SELinux labels. This was testing during the the prep phase, e.g. see
# usr/share/rear/prep/RSYNC/GNU/Linux/200_selinux_in_use.sh script.
# When proper SELinux handling is not possible above mentioned script will create the file
# $opath/selinux.autorelabel. Therefore, in this script we check if this file exist and when the
# answer is yes force auto relabeling the files after the reboot to have a correct SELinux labeled system.

# If selinux was turned off for the backup we have to label the
local scheme=$( url_scheme $BACKUP_URL )
local path=$( url_path $BACKUP_URL )
local opath=$( backup_path $scheme $path )

if test -f "$opath/selinux.autorelabel" ; then
    touch $TARGET_FS_ROOT/.autorelabel
    Log "Created /.autorelabel file : after reboot SELinux will relabel all files"

    # If we are in enforcing, we should try to relabel before the reboot, because if some files
    # are not correctly labelled, system may not be able to start the autorelabel service (ie: /etc/localtime)

    test $( grep "SELINUX=enforcing" $TARGET_FS_ROOT/etc/selinux/config ) || return 0

    local policy=$( grep "^SELINUXTYPE" $TARGET_FS_ROOT/etc/selinux/config | sed 's/SELINUXTYPE=//' )

    LogPrint "We try to restore the selinux labels before the first reboot because the configuration is enforcing and autorelabel may fail. \n
        This can take several minutes."

    if [[ -d "$TARGET_FS_ROOT/etc/selinux/${policy}/" ]] ; then
         #setfiles -c $TARGET_FS_ROOT/etc/selinux/${policy}/policy/policy.*  $TARGET_FS_ROOT/etc/selinux/${policy}/contexts/files/file_contexts
         chroot $TARGET_FS_ROOT /usr/sbin/setfiles /etc/selinux/${policy}/contexts/files/file_contexts /
    else
        LogPrint "The configured selinux policy $policy is not accessible in default path $TARGET_FS_ROOT/etc/selinux/${policy}/. \n
        If the first boot fails, please add 'enforcing=0' on kernel command line, and an autorelabel should fix the labels."
    fi
fi

