# Store settings for write-protected file systems in the rescue configuration.

{
    echo "# The following lines were added by 490_store_write_protect_settings.sh"

    echo "WRITE_PROTECTED_UUIDS=( ${WRITE_PROTECTED_UUIDS[*]} )"

    echo -n "WRITE_PROTECTED_FS_LABEL_PATTERNS=("
    for prefix in "${WRITE_PROTECTED_FS_LABEL_PATTERNS[@]}"; do
        [[ -n "$prefix" ]] && echo -n " '$prefix'"
    done
    echo " )"

    echo ""
} >> "$ROOTFS_DIR/etc/rear/rescue.conf"
