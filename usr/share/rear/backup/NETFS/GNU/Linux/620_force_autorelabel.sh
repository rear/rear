# Create selinux.autorelabel file in the backup location when backup does not preserve SELinux contexts

# Only create autorelabel file if SELinux is in use and backup method does not support SELinux contexts
is_true "$SELINUX_IN_USE" || return 0
is_true "$NETFS_SELINUX" && return 0

local scheme="$(url_scheme "$BACKUP_URL")"
local path="$(url_path "$BACKUP_URL")"
local opath="$(backup_path "$scheme" "$path")"
if [ -d "${opath}" ]; then
    if [ ! -f "${opath}/selinux.autorelabel" ]; then
        > "${opath}/selinux.autorelabel" || Error "Failed to create selinux.autorelabel on ${opath}"
    fi
fi
Log "Trigger (forced) autorelabel (SELinux) file"
