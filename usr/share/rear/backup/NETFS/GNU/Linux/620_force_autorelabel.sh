# Create selinux.autorelabel file in the backup location when SELinux was stopped during backup

[ -f $TMP_DIR/force.autorelabel ] && {
    local scheme="$(url_scheme "$BACKUP_URL")"
    local path="$(url_path "$BACKUP_URL")"
    local opath="$(backup_path "$scheme" "$path")"
    if [ -d "${opath}" ]; then
        if [ ! -f "${opath}/selinux.autorelabel" ]; then
            > "${opath}/selinux.autorelabel" || Error "Failed to create selinux.autorelabel on ${opath}"
        fi
    fi
    Log "Trigger (forced) autorelabel (SELinux) file"
}
