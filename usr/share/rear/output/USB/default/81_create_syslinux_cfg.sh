# Create a suitable syslinux configuration based on capabilities

NETFS_PREFIX=rear/$(uname -n)/$(date +%Y%m%d.%H%S)
USB_SYSLINUX_DIR=$BUILD_DIR/netfs/boot/syslinux
USB_REAR_DIR=$BUILD_DIR/netfs/$NETFS_PREFIX

if [[ ! -d "$USB_SYSLINUX_DIR" ]]; then
    mkdir -vp "$USB_SYSLINUX_DIR" >&8 || Error "Could not create USB syslinux dir [$USB_SYSLINUX_DIR] !"
fi

### We generate a main syslinux.cfg in /boot/syslinux that consist of all
### default functionality
Log "Create boot/syslinux/syslinux.cfg"
(

    cat <<EOF >&4
serial 0 115200
timeout 300
#noescape 1
F1 /boot/syslinux/rear.help
include custom.cfg
menu title Relax and Recover v$VERSION

### Include generated configuration
include rear.cfg

menu separator

EOF

    # Use menu system, if menu.c32 is available
    if [[ -r "$USB_SYSLINUX_DIR/menu.c32" ]]; then
        echo "default menu.c32" >&4
    fi

    cat <<EOF >&4
label -
    menu label Other actions
    menu disable

label help
    menu label ^Help for Relax and Recover
    menu help rear.help

EOF

    # Use chain booting for booting disk, if chain.c32 is available
    if [[ -r "$USB_SYSLINUX_DIR/chain.c32" ]]; then
        cat <<EOF >&4
ontimeout boothd0
label boothd0
    menu label ^Boot local disk hd0
    menu default
    kernel chain.c32
    append hd0

label bootlocal
    menu label Boot ^First BIOS disk
    text help
    Use this when booting from local disk hd0 does not work !
    endtext
    localboot 0x80

EOF
    else
        cat <<EOF >&4
ontimeout bootlocal
label bootlocal
    menu label Boot ^First BIOS disk
    text help
    Use this when booting from local disk hd0 does not work !
    endtext
    localboot 0x80

EOF
    fi
    cat <<EOF >&4
label bootnext
    menu label Boot ^Next device
    text help
    Boot from the next device in the BIOS boot order list.
    endtext
    localboot -1

EOF

    if [[ -r "$USB_SYSLINUX_DIR/memtest" ]]; then
        echo -e "label memtest\n    menu label ^Memory test\n    kernel memtest\n" >&4
    fi

    if [[ -r "$USB_SYSLINUX_DIR/hdt.c32" ]]; then
        echo -e "label hdt\n    menu label Hardware ^Detection tool\n    kernel hdt.c32\n" >&4
    fi

#    echo -e "label -\n    menu label ^Exit menu\n    menu quit\n" >&4

    if [[ -r "$USB_SYSLINUX_DIR/poweroff.com" ]]; then
        echo -e " label poweroff\n menu label ^Power off system\n kernel poweroff.com\n" >&4
    fi

) 4>$USB_SYSLINUX_DIR/syslinux.cfg

if [[ ! -d "$USB_REAR_DIR" ]]; then
    mkdir -vp "$USB_REAR_DIR" >&8 || Error "Could not create USB rear dir [$USB_REAR_DIR] !"
fi

### We generate a single syslinux.cfg for the current system
Log "Create $NETFS_PREFIX/syslinux.cfg"
time=$(basename $USB_REAR_DIR)
cat <<EOF >$USB_REAR_DIR/syslinux.cfg
label $(uname -n)-$time
    menu label ${time:0:4}-${time:4:2}-${time:6:2} ${time:9:2}:${time:11:2}
    text help
    ReaR rescue image for $(uname -n) at ${time:0:4}-${time:4:2}-${time:6:2} ${time:9:2}:${time:11:2}
    Config BACKUP=$BACKUP and OUTPUT=$OUTPUT using kernel $(uname -r)
    endtext
    kernel /$NETFS_PREFIX/kernel
    append initrd=/$NETFS_PREFIX/initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE
EOF

### We generate a rear.cfg based on existing rear syslinux.cfg files.
Log "Create boot/syslinux/rear.cfg"
(

    oldsystem=
    for file in $(cd $BUILD_DIR/netfs; ls rear/*/????????.????/syslinux.cfg); do
        dir=$(dirname $file)
        time=$(basename $dir)
        system=$(basename $(dirname $dir))

        Log "Processing $file"
        if [[ "$system" != "$oldsystem" ]]; then
            if [[ "$oldsystem" ]]; then
                # Close previous submenu
                echo "menu end" >&4
            else
                # Begin recovery header at top
                echo -e "label -\n    menu label Recovery images\n    menu disable" >&4
            fi

            # Begin submenu
            echo -e "\nmenu begin $system\n    menu label $system\n" >&4
        fi

        # Include entry
        echo "    include /$file" >&4
        oldsystem=$system
    done

    if [[ "$oldsystem" ]]; then
        # Close last submenu
        echo -e "\n    menu separator\n" >&4
        echo -e "    label -\n        menu label ^Back\n        menu default\n        menu exit\n" >&4
        echo "menu end" >&4
    fi

) 4>$USB_SYSLINUX_DIR/rear.cfg

echo "Placeholder for Relax and Recover HELP" >$USB_SYSLINUX_DIR/rear.help

Log "Created syslinux configuration"
