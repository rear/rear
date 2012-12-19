# when the variable BACKUP_SELINUX_DISABLE is unset then silently return
[[ -z "$BACKUP_SELINUX_DISABLE" ]] && return

# force relabeling after reboot of the recovered system
touch /mnt/local/.autorelabel
Log "Created /.autorelabel file : after reboot SELinux will relabel all files"
