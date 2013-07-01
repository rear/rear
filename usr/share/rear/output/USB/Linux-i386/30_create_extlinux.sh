# Create a suitable syslinux configuration based on capabilities

function get_usb_syslinux_version {
    for file in $BUILD_DIR/outputfs/{boot/syslinux,}/{ld,ext}linux.sys; do
        if [[ -s "$file" ]];  then
            strings $file | grep -P -m1 "^(EXT|SYS)LINUX \\d+.\\d+" | cut -d' ' -f2
            return 0
        fi
    done
    return 1
}

function syslinux_needs_update {
    local usb_syslinux_version=$(get_usb_syslinux_version)
    local syslinux_version=$(get_syslinux_version)

    Log "USB syslinux version: $usb_syslinux_version"
    Log "System syslinux version: $syslinux_version"
    if [[ "$usb_syslinux_version" ]] && version_newer "$usb_syslinux_version" "$syslinux_version"; then
        Log "No need to update syslinux on USB media (at version $usb_syslinux_version)."
        return 1
    else
        if [[ "$FEATURE_SYSLINUX_SUBMENU" ]]; then
            Log "Beware that older entries may not appear in the syslinux menu."
        fi
        return 0
    fi
}

function syslinux_has {
    local file="$1"

    if [[ -e "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/$file" ]]; then
        if [[ "$SYSLINUX_NEEDS_UPDATE" ]]; then
            if [[ -e "$SYSLINUX_DIR/$file" ]]; then
                cp -f $v "$SYSLINUX_DIR/$file" "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/$file" >&2
            else
                # Make sure we don't have any older copies on USB media
                rm -f $v "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/$file" >&2
                return 1;
            fi
        else
            return 0
        fi
    else
        if [[ -e "$SYSLINUX_DIR/$file" ]]; then
            cp $v "$SYSLINUX_DIR/$file" "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/$file" >&2
        else
            return 1
        fi
    fi
}

# FIXME: Syslinux older than 3.62 do have menu.c32 but not submenu support
#        We simplify by disabling MENU support for everything older than 3.62
function syslinux_write {
    if [[ "$@" ]]; then
        echo "$@" | syslinux_write
    elif [[ "$FEATURE_SYSLINUX_SUBMENU" ]]; then
        cat >&4
    else
        awk '
BEGIN {
    IGNORECASE=1
    IN_TEXT=0
    IGNORE=0
}

/DEFAULT MENU.C32/ { IGNORE=1 }
/ENDTEXT/ { IN_TEXT=0 }
/LABEL -/ { IGNORE=1 }
/MENU / { IGNORE=1 }
/TEXT HELP/ { IN_TEXT=1 }

{
    if (IN_TEXT) { IGNORE=1 }
    if (! IGNORE) {
        print
#    } else {
#        print "#" $0
    }
    if (! IN_TEXT) { IGNORE=0 }
}' >&4
    fi
}

if syslinux_needs_update; then
    SYSLINUX_NEEDS_UPDATE="y"
fi
set_syslinux_features $(get_usb_syslinux_version)

case "$WORKFLOW" in
    (mkbackup) usb_label_workflow="backup";;
    (mkrescue) usb_label_workflow="rescue image";;
    (*) BugError "Workflow $WORKFLOW should not run this script."
esac

USB_REAR_DIR="$BUILD_DIR/outputfs/$USB_PREFIX"
if [ ! -d "$USB_REAR_DIR" ]; then
    mkdir -p $v "$USB_REAR_DIR" >&8
    StopIfError "Could not create USB rear dir [$USB_REAR_DIR] !"
fi

# We generate a single syslinux.cfg for the current system
Log "Creating $USB_PREFIX/syslinux.cfg"
time=$(basename $USB_REAR_DIR)
syslinux_write <<EOF 4>"$USB_REAR_DIR/syslinux.cfg"
label $HOSTNAME-$time
    menu label ${time:0:4}-${time:4:2}-${time:6:2} ${time:9:2}:${time:11:2} $usb_label_workflow
    say $HOSTNAME-$time - Recover $HOSTNAME $usb_label_workflow ($time)
    text help
Relax-and-Recover v$VERSION - $usb_label_workflow using kernel $(uname -r) ${IPADDR:+on $IPADDR}
${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${BACKUP_URL:+BACKUP_URL=$BACKUP_URL}
    endtext
    kernel /$USB_PREFIX/kernel
    append initrd=/$USB_PREFIX/initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE

label $HOSTNAME-$time
    menu label ${time:0:4}-${time:4:2}-${time:6:2} ${time:9:2}:${time:11:2} $usb_label_workflow - AUTOMATIC RECOVER
    say $HOSTNAME-$time - Recover $HOSTNAME $usb_label_workflow ($time)
    text help
Relax-and-Recover v$VERSION - $usb_label_workflow using kernel $(uname -r) ${IPADDR:+on $IPADDR}
${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${BACKUP_URL:+BACKUP_URL=$BACKUP_URL}
    endtext
    kernel /$USB_PREFIX/kernel
    append initrd=/$USB_PREFIX/initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE auto_recover

EOF

# Clean up older images of a given system, but keep USB_RETAIN_BACKUP_NR
# entries for backup and rescue
backup_count=${USB_RETAIN_BACKUP_NR:-2}
rescue_count=${USB_RETAIN_BACKUP_NR:-2}
for rear_run in $(ls -dt $BUILD_DIR/outputfs/rear/$HOSTNAME/*); do
    backup_name=$rear_run/${BACKUP_PROG_ARCHIVE}${BACKUP_PROG_SUFFIX}${BACKUP_PROG_COMPRESS_SUFFIX}
    if [[ -e $backup_name ]] ; then
        backup_count=$((backup_count - 1))
        if (( backup_count < 0 )); then
            Log "Remove older backup directory $rear_run"
            rm -rf $v $rear_run >&8
        fi
    else
        rescue_count=$((rescue_count - 1))
        if (( rescue_count < 0 )); then
            Log "Remove older rescue directory $rear_run"
            rm -rf $v $rear_run >&8
        fi
    fi
done

# We generate a rear syslinux.cfg based on existing rear syslinux.cfg files.
Log "Creating /rear/syslinux.cfg"
{
    syslinux_write <<EOF
label rear
    say Relax-and-Recover - Recover $(uname -n) from $time
    menu hide
    kernel $HOSTNAME-$time

EOF

    oldsystem=
    # TODO: Sort systems by name, but also sort timestamps in reverse order
    for file in $(cd $BUILD_DIR/outputfs; find rear/*/* -name syslinux.cfg); do
        dir=$(dirname $file)
        time=$(basename $dir)
        system=$(basename $(dirname $dir))

        Log "Processing $file"
        if [[ "$system" != "$oldsystem" ]]; then
            if [[ "$oldsystem" ]]; then
                # Close previous submenu
                syslinux_write "menu end"
            else
                # Begin recovery header at top
                syslinux_write <<EOF
label -
    menu label Recovery images
    menu disable

EOF
            fi

            # Begin submenu
            syslinux_write <<EOF

menu begin $system
    menu label $system
    text help
Recover backup of $system to this system.
    endtext

EOF
        fi

        # Include entry
        if [[ "$FEATURE_SYSLINUX_INCLUDE" ]]; then
            syslinux_write "    include /$file"
        else
            cat $BUILD_DIR/outputfs/$file >&4
        fi
        oldsystem=$system
    done

    if [[ "$oldsystem" ]]; then
        # Close last submenu
        syslinux_write <<EOF

    menu separator

    label -
        menu label ^Back
        menu default
        text help
Return to the main menu
        endtext
        menu exit

menu end

EOF
    fi

} 4>"$BUILD_DIR/outputfs/rear/syslinux.cfg"

if [ ! -d "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX" ]; then
    mkdir -p $v "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX" >&8
    StopIfError "Could not create USB syslinux dir [$BUILD_DIR/outputfs/$SYSLINUX_PREFIX] !"
fi

echo "$VERSION_INFO" >$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/message

# We generate a main extlinux.conf in /boot/syslinux that consist of all
# default functionality
Log "Creating $SYSLINUX_PREFIX/extlinux.conf"
{
    # Enable serial console, unless explicitly disabled
    if [[ "$USE_SERIAL_CONSOLE" =~ ^[yY1] ]]; then
        for devnode in $(ls /dev/ttyS[0-9]* | sort); do
            speed=$(stty -F $devnode 2>&8 | awk '/^speed / { print $2 }')
            if [ "$speed" ]; then
                syslinux_write "serial ${devnode##/dev/ttyS} $speed"
            fi
        done
    fi

    syslinux_write "display message"

    # Add useful syslinux utilities, if present
    syslinux_has "cat.c32"
    syslinux_has "config.c32"
    syslinux_has "cmd.c32"
    syslinux_has "cpuid.c32"
    syslinux_has "disk.c32"
    syslinux_has "host.c32"
    syslinux_has "kbdmap.c32"
    syslinux_has "ls.c32"
    syslinux_has "lua.c32"
    syslinux_has "rosh.c32"
    syslinux_has "sysdump.c32"
    syslinux_has "vesamenu.c32"

    # Add needed libraries for syslinux v5 and hdt
    syslinux_has "ldlinux.c32"
    syslinux_has "libcom32.c32"
    syslinux_has "libgpl.c32"
    syslinux_has "libmenu.c32"
    syslinux_has "libutil.c32"

    if [ -r $(get_template "rear.help") ]; then
        cp $v $(get_template "rear.help") "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/rear.help" >&8
        syslinux_write <<EOF
say F1 - Show help
F1 /boot/syslinux/rear.help
menu tabmsg Press [Tab] to edit options or [F1] for help
EOF
    fi

    # Use menu system, if menu.c32 is available
    if syslinux_has "menu.c32"; then
        syslinux_write "default menu.c32"
    fi

    syslinux_write <<EOF
timeout 300
#noescape 1

menu title $PRODUCT v$VERSION
EOF

if [[ "$FEATURE_SYSLINUX_INCLUDE" ]]; then
    syslinux_write <<EOF
### Add custom items to your configuration by creating custom.cfg
include custom.cfg

### Include generated configuration
include /rear/syslinux.cfg
EOF
else
    cat "$BUILD_DIR/outputfs/rear/syslinux.cfg" >&4
fi

syslinux_write <<EOF
menu separator

label -
    menu label Other actions
    menu disable

EOF

    if [[ "$FEATURE_SYSLINUX_MENU_HELP" && -r $(get_template "rear.help") ]]; then
        syslinux_write <<EOF
label help
    menu label ^Help for Relax-and-Recover
    text help
More information about Relax-and-Recover and the steps for recovering your system
    endtext
    menu help rear.help

EOF
    fi

    # Use chain booting for booting disk, if chain.c32 is available
    if syslinux_has "chain.c32"; then
        syslinux_write <<EOF
ontimeout boothd1
label boothd1
    say boothd1 - boot second local disk
    menu label Boot ^Local disk (hd1)
    menu default
    kernel chain.c32
    append hd1

label bootlocal
    say bootlocal - boot second local bios disk
    menu label Boot ^BIOS disk (0x81)
    text help
Use this when booting from local disk 0x81 does not work !
    endtext
    localboot 0x81

EOF
    else
        syslinux_write <<EOF
ontimeout bootlocal
label bootlocal
    say bootlocal - boot second local bios disk
    menu label Boot ^BIOS disk (0x81)
    localboot 0x81

EOF
    fi

    syslinux_write <<EOF
label bootnext
    menu label Boot ^Next device
    text help
Boot from the next device in the BIOS boot order list.
    endtext
    localboot -1

EOF

    if syslinux_has "hdt.c32"; then
        if [ -r "/usr/share/hwdata/pci.ids" ]; then
            cp $v "/usr/share/hwdata/pci.ids" "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/pci.ids" >&8
        elif [ -r "/usr/share/pci.ids" ]; then
            cp $v "/usr/share/pci.ids" "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/pci.ids" >&8
        fi
        if [ -r "/lib/modules/$(uname -r)/modules.pcimap" ]; then
            cp $v "/lib/modules/$KERNEL_VERSION/modules.pcimap" "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/modules.pcimap" >&8
        fi
        syslinux_write <<EOF
label hdt
    say hdt - Hardware Detection Tool
    menu label Hardware ^Detection tool
    text help
Information about your current hardware configuration
    endtext
    kernel hdt.c32

EOF
    fi

    # You need the memtest86+ package installed for this to work
    MEMTEST_BIN=$(ls -d /boot/memtest86+-* 2>&8 | tail -1)
    if [[ "$MEMTEST_BIN" != "." && -r "$MEMTEST_BIN" ]]; then
        cp $v "$MEMTEST_BIN" "$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/memtest" >&8
        syslinux_write <<EOF
label memtest
    say memtest - Run memtest86+
    menu label ^Memory test
    text help
Test your memory for problems
    endtext
    kernel memtest
    append -

EOF
    fi

#    echo -e "label -\n    menu label ^Exit menu\n    menu quit\n" >&4

    if syslinux_has "reboot.c32"; then
        syslinux_write <<EOF
label reboot
    say reboot - Reboot the system
    menu label ^Reboot system
    text help
Reboot the system now
    endtext
    kernel reboot.c32

EOF
    fi

    if syslinux_has "poweroff.com"; then
        syslinux_write <<EOF
label poweroff
    say poweroff - Power off the system
    menu label ^Power off system
    text help
Power off the system now
    endtext
    kernel poweroff.com

EOF
    fi

} 4>"$BUILD_DIR/outputfs/$SYSLINUX_PREFIX/extlinux.conf"

Log "Created extlinux configuration '$SYSLINUX_PREFIX/extlinux.conf'"
