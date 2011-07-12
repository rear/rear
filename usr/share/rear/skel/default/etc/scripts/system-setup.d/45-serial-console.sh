### Enable serial console
###

if ! type -p stty &>/dev/null; then
    echo "WARNING: stty not found, serial console disabled." >&2
    return
fi

if type -p getty &>/dev/null; then
    # Debian, Ubuntu,...
    GETTY=getty
elif type -p agetty &>/dev/null; then
    # Fedora, RHEL, SLES,...
    GETTY=agetty
else
    echo "WARNING: getty or agetty not found, serial console disabled." >&2
    return
fi

for devnode in $(ls /dev/ttyS[0-9]* | sort); do
    speed=$(stty -F $devnode 2>/dev/null | awk '/^speed / { print $2 }')
    if [ "$speed" ]; then
        echo "s${devnode##/dev/ttyS}:2345:respawn:/sbin/$GETTY $speed ${devnode##/dev/} vt100" >>$ROOTFS_DIR/etc/inittab
        echo "Serial console support enabled for ${devnode##/dev/} at speed $speed" >&2
    fi
done

init q
