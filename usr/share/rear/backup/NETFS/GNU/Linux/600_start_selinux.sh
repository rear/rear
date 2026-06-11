# Start SELinux if it was stopped - check presence of $TMP_DIR/selinux.mode
[[ -f $TMP_DIR/selinux.mode ]] && {
    local scheme="$( url_scheme "$BACKUP_URL" )"
    local path="$( url_path "$BACKUP_URL" )"
    local opath="$( backup_path "$scheme" "$path" )"
    cat $TMP_DIR/selinux.mode > $SELINUX_ENFORCE
    Log "Restored original SELinux mode"
    touch "${opath}/selinux.autorelabel"
    Log "Trigger autorelabel (SELinux) file"
}
