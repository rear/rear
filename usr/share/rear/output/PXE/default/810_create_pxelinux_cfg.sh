# 81_create_pxelinux_cfg.sh
#
# create pxelinux config on PXE server for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# we got PXE_KERNEL and PXE_INITRD set in the previous script

if [[ ! -z "$PXE_CONFIG_URL" ]] ; then
    # E.g. PXE_CONFIG_URL=nfs://server/export/nfs/tftpboot/pxelinux.cfg
    # Better be sure that on 'server' the directory /export/nfs/tftpboot/pxelinux.cfg exists
    local scheme=$( url_scheme $PXE_CONFIG_URL )
    local path=$( url_path $PXE_CONFIG_URL )
    mkdir -p $v "$BUILD_DIR/tftpbootfs" >&2
    StopIfError "Could not mkdir '$BUILD_DIR/tftpbootfs'"
    AddExitTask "rm -Rf $v $BUILD_DIR/tftpbootfs >&2"
    mount_url $PXE_CONFIG_URL $BUILD_DIR/tftpbootfs $BACKUP_OPTIONS
    PXE_LOCAL_PATH=$BUILD_DIR/tftpbootfs
else
    # legacy way using PXE_LOCAL_PATH default
    PXE_LOCAL_PATH=$PXE_CONFIG_PATH
fi

# PXE_CONFIG_PREFIX is a "string" (by default rear-) - is the name of PXE boot configuration of $HOSTNAME
PXE_CONFIG_FILE="${PXE_CONFIG_PREFIX}$HOSTNAME"
if [[ ! -z "$PXE_CONFIG_URL" ]] ; then
    if is_true "$PXE_CONFIG_GRUB_STYLE" ; then
        make_pxelinux_config_grub >"$PXE_LOCAL_PATH/$PXE_CONFIG_FILE"
    else
        make_pxelinux_config >"$PXE_LOCAL_PATH/$PXE_CONFIG_FILE"
    fi
    chmod 444 "$PXE_LOCAL_PATH/$PXE_CONFIG_FILE"
else
    # legacy way using PXE_LOCAL_PATH default
    cat >"$PXE_LOCAL_PATH/$PXE_CONFIG_FILE" <<EOF
    $(test -s $(get_template "PXE_pxelinux.cfg") && cat $(get_template "PXE_pxelinux.cfg"))
    display $OUTPUT_PREFIX_PXE/$PXE_MESSAGE
    say ----------------------------------------------------------
    say rear = disaster recover this system with Relax-and-Recover
    label rear
	kernel $OUTPUT_PREFIX_PXE/$PXE_KERNEL
	append initrd=$OUTPUT_PREFIX_PXE/$PXE_INITRD root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE $PXE_RECOVER_MODE
EOF
fi


pushd "$PXE_LOCAL_PATH" >/dev/null
StopIfError "PXE_CONFIG_PATH [$PXE_CONFIG_PATH] does not exist !"
if test "$PXE_CREATE_LINKS" -a "$PXE_REMOVE_OLD_LINKS" ; then
	# remove old links
	find . -maxdepth 1 -type l | \
		while read file ; do
			if test "$(readlink -s $file)" = "$PXE_CONFIG_FILE" ; then
				rm -f $file
			fi
		done
fi

# When using Grub network boot via tftp/bootp,
# the client is looking at a file named "grub.cfg-01-<MAC>"
# or grub.cfg-<IP in hex>. It is like PXE, but prefixed with "grub.cfg-"
if is_true $PXE_CONFIG_GRUB_STYLE ; then
    pxe_link_prefix="grub.cfg-"
else
    pxe_link_prefix=""
fi

case "$PXE_CREATE_LINKS" in
	IP)
		# look only at IPv4 and skip localhost (127...)
		ip a | grep inet\ | grep -v inet\ 127 | \
			while read inet IP junk ; do
				IP=${IP%/*}
                # check if gethostip is available.
                if has_binary gethostip &>/dev/null ; then
    				ln -sf $v "$PXE_CONFIG_FILE" $(gethostip -x $IP) >&2
    				# to capture the whole subnet as well
    				ln -sf $v "$PXE_CONFIG_FILE" $(gethostip -x $IP | cut -c 1-6) >&2
                else
                # if gethostip is not available on your platform (like ppc64),
                # use awk to generate IP in hex mode.
                    ln -sf $v "$PXE_CONFIG_FILE" $pxe_link_prefix$(printf '%02X' ${IP//./ }) >&2
                    # to capture the whole subnet as well
    				ln -sf $v "$PXE_CONFIG_FILE" $pxe_link_prefix$(printf '%02X' ${IP//./ } | cut -c 1-6) >&2
                fi
			done
		;;
	MAC)
		# look at all devices that have link/ether
		ip l | grep link/ether | \
			while read link mac junk ; do
				ln -sf $v "$PXE_CONFIG_FILE" 01-${mac//:/-} >&2
			done
		;;
	"")
		Log "Not creating symlinks to pxelinux configuration file"
		;;
	*)
		Error "Invalid PXE_CREATE_LINKS specified, must be MAC or IP or ''"
		;;
esac
popd >/dev/null

if [[ ! -z "$PXE_CONFIG_URL" ]] ; then
    LogPrint "Created pxelinux config '${PXE_CONFIG_PREFIX}$HOSTNAME' and symlinks for $PXE_CREATE_LINKS adresses in $PXE_CONFIG_URL"
    umount_url $PXE_TFTP_URL $BUILD_DIR/tftpbootfs
    rmdir $BUILD_DIR/tftpbootfs >&2
    if [[ $? -eq 0 ]] ; then
        RemoveExitTask "rm -Rf $v $BUILD_DIR/tftpbootfs >&2"
    fi
else
    LogPrint "Created pxelinux config '${PXE_CONFIG_PREFIX}$HOSTNAME' and symlinks for $PXE_CREATE_LINKS adresses in $PXE_CONFIG_PATH"
    # Add to result files
    RESULT_FILES+=( "$PXE_LOCAL_PATH/$PXE_CONFIG_FILE" )
fi
