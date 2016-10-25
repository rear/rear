# 81_create_pxelinux_cfg.sh
#
# create pxelinux config on PXE server for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# we got PXE_KERNEL and PXE_INITRD set in the previous script

# TODO: mount remote PXE server
PXE_LOCAL_PATH=$PXE_CONFIG_PATH
PXE_CONFIG_FILE="${PXE_CONFIG_PREFIX}$HOSTNAME"
cat >"$PXE_LOCAL_PATH/$PXE_CONFIG_FILE" <<EOF
$(test -s $(get_template "PXE_pxelinux.cfg") && cat $(get_template "PXE_pxelinux.cfg"))
display $OUTPUT_PREFIX_PXE/$PXE_MESSAGE
say ----------------------------------------------------------
say rear = disaster recover this system with Relax-and-Recover
label rear
	kernel $OUTPUT_PREFIX_PXE/$PXE_KERNEL
	append initrd=$OUTPUT_PREFIX_PXE/$PXE_INITRD root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE
EOF

pushd "$PXE_LOCAL_PATH" >&8
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

case "$PXE_CREATE_LINKS" in
	IP)
		# look only at IPv4 and skip localhost (127...)
		ip a | grep inet\ | grep -v inet\ 127 | \
			while read inet IP junk ; do
				IP=${IP%/*}
				ln -sf $v "$PXE_CONFIG_FILE" $(gethostip -x $IP) >&2
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
popd >&8

#TODO: umount remote PXE server

LogPrint "Created pxelinux config '${PXE_CONFIG_PREFIX}$HOSTNAME' and symlinks for $PXE_CREATE_LINKS adresses in $PXE_CONFIG_PATH"

# Add to result files
RESULT_FILES=( "${RESULT_FILES[@]}" "$PXE_LOCAL_PATH/$PXE_CONFIG_FILE" )
