
# Activating multipath if BOOT_OVER_SAN variable is true
# or if multipath device are present in LAYOUT_FILE
if grep -q '^multipath' "$LAYOUT_FILE" || is_true "$BOOT_OVER_SAN" ; then
    Log "Activating multipath"

    # We need to create a multipath.conf if it does not exists (needed by Fedora based OS)
    if [ ! -f /etc/multipath.conf ] ; then
        if type mpathconf &> /dev/null ; then
            LogPrint "Using mpathconf to configure multipath with friendly_names and find_multipath options"

            # /etc/multipath dir need to be present before mpathconf runs
            [ ! -d /etc/multipath ] && mkdir -p /etc/multipath

            # create default multipath.conf with friendly_names and find_multipath options
            # load mudules and start multipath discovery
            mpathconf --enable --user_friendly_names y --find_multipaths y --with_module y --with_multipathd y
        else
            LogPrint "mpathconf not found... activating multipath with minimal options"
            touch /etc/multipath.conf
        fi
    fi

    modprobe dm-multipath >&2
    multipath >&2
    if [ $? -ne 0 ] ; then
        LogPrint "Failed to activate multipath, or no multipath device found."
        rear_shell "Did you activate the multipath devices?"
    else
        LogPrint "multipath activated"
        dmsetup ls --target multipath
    fi
fi

### Create multipath devices (at least partitions on them).
create_multipath() {
    local multipath device
    read multipath device junk < <(grep "multipath $1 " "$LAYOUT_FILE")

    create_partitions "$device"
}
