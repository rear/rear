# 810_create_pxelinux_cfg.sh
#
# Create PXELINUX config on PXE server for Relax-and-Recover.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# We got PXE_KERNEL and PXE_INITRD set in the previous script.

local pxe_local_path
if test "$PXE_CONFIG_URL" ; then
    # E.g. PXE_CONFIG_URL=nfs://server/export/nfs/tftpboot/pxelinux.cfg
    # On 'server' the directory /export/nfs/tftpboot/pxelinux.cfg must exist.
    local scheme="$( url_scheme "$PXE_CONFIG_URL" )"
    # We need filesystem access to the destination (schemes like ftp:// are not supported)
    if ! scheme_supports_filesystem $scheme ; then
        Error "Scheme $scheme for PXE output not supported, use a scheme that supports mounting (like nfs: )"
    fi
    mount_url "$PXE_CONFIG_URL" "$BUILD_DIR/tftpbootfs" $BACKUP_OPTIONS
    pxe_local_path="$BUILD_DIR/tftpbootfs"
else
    # legacy way using pxe_local_path default
    pxe_local_path="$PXE_CONFIG_PATH"
fi

# PXE_CONFIG_PREFIX is by default 'rear-' (see default.conf).
# pxe_config_file contains the PXELINUX boot configuration of $HOSTNAME
local pxe_config_file="${PXE_CONFIG_PREFIX}$HOSTNAME"
if test "$PXE_CONFIG_URL" ; then
    if is_true "$PXE_CONFIG_GRUB_STYLE" ; then
        make_pxelinux_config_grub >"$pxe_local_path/$pxe_config_file"
    else
        make_pxelinux_config >"$pxe_local_path/$pxe_config_file"
    fi
    chmod 444 "$pxe_local_path/$pxe_config_file"
else
    # legacy way using pxe_local_path default
    local pxe_template_file="$( get_template "PXE_pxelinux.cfg" )"
    cat >"$pxe_local_path/$pxe_config_file" <<EOF
    $( test -s "$pxe_template_file" && cat "$pxe_template_file" )
    display $OUTPUT_PREFIX_PXE/$PXE_MESSAGE
    say ----------------------------------------------------------
    say rear = disaster recover this system with Relax-and-Recover
    label rear
    kernel $OUTPUT_PREFIX_PXE/$PXE_KERNEL
    append initrd=$OUTPUT_PREFIX_PXE/$PXE_INITRD root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE $PXE_RECOVER_MODE
EOF
fi

pushd "$pxe_local_path" >/dev/null || Error "pxe_local_path '$pxe_local_path' does not exist"

if test "$PXE_CREATE_LINKS" -a "$PXE_REMOVE_OLD_LINKS" ; then
    # remove old symlinks
    local symlink
    find . -maxdepth 1 -type l | while read symlink ; do
        test "$( readlink -s $symlink )" = "$pxe_config_file" && rm -f $symlink
    done
fi

# When using Grub network boot via tftp/bootp,
# the client is looking at a file named 'grub.cfg-01-<MAC>' or 'grub.cfg-<IP in hex>'
# which is like PXE, but prefixed with 'grub.cfg-'
local pxe_link_prefix=""
is_true $PXE_CONFIG_GRUB_STYLE && pxe_link_prefix="grub.cfg-"

local headword IP MAC junk
case "$PXE_CREATE_LINKS" in
    (IP)
        # consider only IPv4 lines 'inet ...' and skip localhost 'inet 127...'
        ip address | grep 'inet ' | grep -v 'inet 127' | while read headword IP junk ; do
            # cut trailing CIDR or netmask e.g. '192.168.100.101/24' -> '192.168.100.101'
            IP=${IP%/*}
            if has_binary gethostip &>/dev/null ; then
                ln -sf $v "$pxe_config_file" $pxe_link_prefix$( gethostip -x $IP )
                # to capture the whole subnet as well
                ln -sf $v "$pxe_config_file" $pxe_link_prefix$( gethostip -x $IP | cut -c 1-6 )
            else
                # if gethostip is not available on your platform like ppc64,
                # use printf to output IP in hex mode
                ln -sf $v "$pxe_config_file" $pxe_link_prefix$( printf '%02X' ${IP//./ } )
                # to capture the whole subnet as well
                ln -sf $v "$pxe_config_file" $pxe_link_prefix$( printf '%02X' ${IP//./ } | cut -c 1-6 )
            fi
        done
        ;;
    (MAC)
        # look at all devices that have link/ether
		ip link | grep 'link/ether' | while read headword MAC junk ; do
            # in MAC replace ':' with '-' e.g. 'a1:b2:c3:d4:e5:f6' -> 'a1-b2-c3-d4-e5-f6'
            ln -sf $v "$pxe_config_file" ${pxe_link_prefix}01-${MAC//:/-}
        done
        ;;
    ("")
        Log "Not creating symlinks to PXELINUX config file '$pxe_config_file' (empty PXE_CREATE_LINKS)"
        ;;
    (*)
        Error "Invalid PXE_CREATE_LINKS '$PXE_CREATE_LINKS' (must be MAC or IP or '')"
        ;;
esac

popd >/dev/null

if test "$PXE_CONFIG_URL" ; then
    LogPrint "Created PXELINUX config '$pxe_config_file' and symlinks for $PXE_CREATE_LINKS adresses in $PXE_CONFIG_URL"
    umount_url "$PXE_TFTP_UPLOAD_URL" "$BUILD_DIR/tftpbootfs"
else
    LogPrint "Created PXELINUX config '$pxe_config_file' and symlinks for $PXE_CREATE_LINKS adresses in $PXE_CONFIG_PATH"
    RESULT_FILES+=( "$pxe_local_path/$pxe_config_file" )
fi
