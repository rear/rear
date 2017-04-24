
# Activating multipath if BOOT_OVER_SAN variable is true.
# or if multipath device are present in LAYOUT_FILE.

# In case of migration to a BOOT_OVER_SAN server, you need to be able
# to detect new multipath device even if there are no multipath device present
# in the Layout file (original machine not multipathed). (#1309)
if grep -q '^multipath' "$LAYOUT_FILE" || is_true "$BOOT_OVER_SAN" ; then
    Log "Activating multipath"

    # We need to create a multipath.conf if it does not exists (needed by Fedora based OS)
    if [ ! -f /etc/multipath.conf ] ; then
        if has_binary mpathconf &> /dev/null ; then
            LogPrint "Using mpathconf to configure multipath with friendly_names and find_multipath options"

            # /etc/multipath dir need to be present before mpathconf runs
            [ ! -d /etc/multipath ] && mkdir -p /etc/multipath

            # create default multipath.conf with friendly_names and find_multipath options
            mpathconf --enable --user_friendly_names y --find_multipaths y --with_module y --with_multipathd y
        else
            # Activate multipath with most commonly used options : user_friendly_names, find_multipaths
            if [[ $OS_VENDOR == SUSE_LINUX ]] && (( $OS_VERSION < 12 )) ; then

                # SLES 11 multipath does not support find_multipaths and does not have /etc/multipath/bindings file
                # which keep relationship between name and uniq ID...
                # It is better to not activate those options by default.
                LogPrint "mpathconf not found... SLES11 detected: activating multipath with minimal options"
                touch /etc/multipath.conf

            else
                LogPrint "mpathconf not found... activating multipath with options : user_friendly_names, find_multipaths)"
            echo "
defaults {
        user_friendly_names yes
        find_multipaths yes
}

blacklist {
}" >> /etc/multipath.conf
            fi
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
