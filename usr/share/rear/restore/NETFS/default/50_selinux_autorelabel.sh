# If selinux was turned off for the backup we have to label the
local scheme=$(url_scheme $OUTPUT_URL)
local path=$(url_path $OUTPUT_URL)
local opath=$(output_path $scheme $path)

[ -f "${opath}/selinux.autorelabel" ] && { \
	touch /mnt/local/.autorelabel
	Log "Created /.autorelabel file : after reboot SELinux will relabel all files"
	}
