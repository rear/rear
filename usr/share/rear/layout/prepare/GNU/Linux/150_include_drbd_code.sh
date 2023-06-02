# Code to create DRBD.

# This requires DRBD configuration present!
create_drbd() {
    local drbd disk resource device junk
    read drbd disk resource device junk < <(grep "^drbd $1 " "$LAYOUT_FILE")

    cat >> "$LAYOUT_CODE" <<EOF
if [ ! -e /proc/drbd ] ; then
    modprobe drbd
fi

mkdir -p /var/lib/drbd

LogPrint "Creating DRBD resource $resource"
if ! drbdadm role $resource &>/dev/null ; then
   drbdadm -- --force create-md $resource
fi

EOF

    # Ask if we need to become primary.
    # When USER_INPUT_DRBD_RESOURCE_BECOMES_PRIMARY has any 'true' value be liberal in what you accept and assume exactly 'yes' was actually meant:
    is_true "$USER_INPUT_DRBD_RESOURCE_BECOMES_PRIMARY" && USER_INPUT_DRBD_RESOURCE_BECOMES_PRIMARY="yes"
    user_input="$( UserInput -I DRBD_RESOURCE_BECOMES_PRIMARY -D no -p "Type 'yes' if you want DRBD resource $resource to become primary" )"
    if [ "$user_input" = "yes" ] ; then
        cat >> "$LAYOUT_CODE" <<-EOF
        if ! drbdadm role $resource &>/dev/null ; then
           drbdadm up $resource
           # Dirty hack against "DRBD9 restore issue, when trying to become primary"
           # cf. https://github.com/rear/rear/issues/2634
           # With DRBD9 there is a new behavior when trying to become primary, without the second node reachable.
           # In this case the command "drbadm -- --overwrite-data-of-peer primary $resource"
           # will end with an error "refusing to be primary while peer is not outdated".
           # A workaround is to use instead the commands
           #   drbdadm del-peer $resource
           #   drbdadm primary $resource --force
           # We assume when "drbadm -- --overwrite-data-of-peer primary $resource"
           # exits with non-zero exit code it is this issue so we try the other commands
           # because we hope things won't get worse this way (but we are no DRBD experts)
           # cf. "Dirty hacks welcome" at https://github.com/rear/rear/wiki/Coding-Style
           if ! drbdadm -- --overwrite-data-of-peer primary $resource ; then
               drbdadm del-peer $resource
               drbdadm primary $resource --force
           fi
        fi
	EOF
    else
        # Mark things which depend on this drbd resource as "done" (recursively).
        mark_tree_as_done "$disk"
        EXCLUDE_RESTORE+=( "$disk" )
    fi
}
