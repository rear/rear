
# Activating multipath if BOOT_OVER_SAN variable is true
# or if multipath device are present in LAYOUT_FILE
if grep -q '^multipath' "$LAYOUT_FILE" || is_true "$BOOT_OVER_SAN" ; then
    Log "Activating multipath"
    modprobe dm-multipath >&2
    [ ! -f /etc/multipath.conf ] && touch /etc/multipath.conf
    multipath >&2
    if [ $? -ne 0 ] ; then
        LogPrint "Failed to activate multipath. Please do this now:"
        rear_shell "Did you activate the multipath devices?"
    fi
fi

### Create multipath devices (at least partitions on them).
create_multipath() {
    local multipath device
    read multipath device junk < <(grep "multipath $1 " "$LAYOUT_FILE")

    create_partitions "$device"
}
