# If selinux was turned off for the backup we have to label the
local scheme=$(url_scheme $BACKUP_URL)
local path=$(url_path $BACKUP_URL)
local opath=$(backup_path $scheme $path)

[ -f "${opath}/selinux.autorelabel" ] && { \
	touch /mnt/local/.autorelabel
	Log "Created /.autorelabel file : after reboot SELinux will relabel all files"
	}
