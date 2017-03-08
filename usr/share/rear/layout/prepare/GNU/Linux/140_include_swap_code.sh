# Code to recreate a swap volume.

# Test for features in mkswap.
# True if mkswap supports the -U option.
FEATURE_MKSWAP_UUID=

mkswap_version=$(get_version mkswap --version)
if version_newer "$mkswap_version" 2.13.1.1; then
    FEATURE_MKSWAP_UUID="y"
fi


create_swap() {
    local swap device uuid label junk
    read swap device uuid label junk < <(grep "^swap ${1#swap:} " "$LAYOUT_FILE")

    if [[ "$FEATURE_MKSWAP_UUID" && -n "${uuid#uuid=}" ]] ; then
        uuid="-U ${uuid#uuid=} "
    else
        uuid=""
    fi

    if [[ -n "${label#label=}" ]] ; then
        label="-L ${label#label=} "
    else
        label=""
    fi

    (
    echo "LogPrint \"Creating swap on $device\""
    echo "mkswap ${uuid}${label}${device} >&2"
    ) >> "$LAYOUT_CODE"
}
