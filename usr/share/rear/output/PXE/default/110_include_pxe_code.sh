# 110_include_pxe_code.sh
#
# Helper functions for PXE output

# First argument is the target URL, second argument is the name of the
# variable to store the mountpoint to.  This is rather cumbersome but we
# can't use stdout to pass the directory because mount_url cannot be used
# in a subshell.
mount_pxe_url() {
    local url="$1"
    local out_var="$2"

    # We need filesystem access to the destination (schemes like ftp:// are not supported)
    local scheme="$( url_scheme "$url" )"
    scheme_supports_filesystem "$scheme" || Error "Scheme $scheme for PXE output not supported, use a scheme that supports mounting (like nfs: )"

    case "$scheme" in
        (file)
            printf -v "$out_var" "%s" "$(url_path "$url")"
            ;;
        (*)
            # tmpdir is used to allow for concurrent mounts
            printf -v "$out_var" "%s" "$(mktemp --tmpdir="$BUILD_DIR" -d pxebootfs-XXX)"
            mount_url "$url" "${!out_var}" $BACKUP_OPTIONS
            ;;
    esac
}
