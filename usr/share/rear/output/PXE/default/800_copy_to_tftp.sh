# 800_copy_to_tftp.sh
#
# copy kernel and initrd to TFTP server for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if [[ ! -z "$PXE_TFTP_URL" ]] ; then
    # E.g. PXE_TFTP_URL=nfs://server/export/nfs/tftpboot
    local scheme=$( url_scheme $PXE_TFTP_URL )

    # We need filesystem access to the destination (schemes like ftp:// are not supported)
    if ! scheme_supports_filesystem $scheme ; then
        Error "Scheme $scheme for PXE output not supported, use a scheme that supports mounting (like nfs: )"
    fi

    mount_url $PXE_TFTP_URL $BUILD_DIR/tftpbootfs $BACKUP_OPTIONS
    # However, we copy under $OUTPUT_PREFIX_PXE directory (usually HOSTNAME) to have different clients on one pxe server
    PXE_TFTP_LOCAL_PATH=$BUILD_DIR/tftpbootfs
    # mode must readable for others for pxe and we copy under the client HOSTNAME (=OUTPUT_PREFIX_PXE)
    mkdir -m 755 -p $v "$BUILD_DIR/tftpbootfs/$OUTPUT_PREFIX_PXE" >&2
    StopIfError "Could not mkdir '$BUILD_DIR/tftpbootfs/$OUTPUT_PREFIX_PXE'"
    PXE_KERNEL="$OUTPUT_PREFIX_PXE/${PXE_TFTP_PREFIX}kernel"
    PXE_INITRD="$OUTPUT_PREFIX_PXE/$PXE_TFTP_PREFIX$REAR_INITRD_FILENAME"
    PXE_MESSAGE="$OUTPUT_PREFIX_PXE/${PXE_TFTP_PREFIX}message"
else
    PXE_TFTP_LOCAL_PATH="$PXE_TFTP_PATH"
    # By default PXE_TFTP_PREFIX=$HOSTNAME. (see conf/default.conf)
    PXE_KERNEL="${PXE_TFTP_PREFIX}kernel"
    PXE_INITRD="$PXE_TFTP_PREFIX$REAR_INITRD_FILENAME"
    PXE_MESSAGE="${PXE_TFTP_PREFIX}message"
    [[ ! -d "$PXE_TFTP_LOCAL_PATH" ]] && mkdir $v -m 750 "$PXE_TFTP_LOCAL_PATH" >&2
fi

# Follow symbolic links to ensure the real content gets copied
# but do not preserve mode,ownership,timestamps (i.e. no -p option) because that may fail (on sshfs) like
# "cp: failed to preserve ownership for '/tmp/rear-efi.XXXXXXXXXX/EFI/BOOT/kernel': Operation not permitted"
cp -L $v "$KERNEL_FILE" "$PXE_TFTP_LOCAL_PATH/$PXE_KERNEL" || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE'"
cp -L $v "$TMP_DIR/$REAR_INITRD_FILENAME" "$PXE_TFTP_LOCAL_PATH/$PXE_INITRD" || Error "Failed to copy initrd '$REAR_INITRD_FILENAME'"
echo "$VERSION_INFO" >"$PXE_TFTP_LOCAL_PATH/$PXE_MESSAGE"
# files must be readable for others for PXE
# files should be writebale by owner or overwriting it on later runs will fail
chmod 644 "$PXE_TFTP_LOCAL_PATH/$PXE_KERNEL"
chmod 644 "$PXE_TFTP_LOCAL_PATH/$PXE_INITRD"
chmod 644 "$PXE_TFTP_LOCAL_PATH/$PXE_MESSAGE"

if [[ ! -z "$PXE_TFTP_URL" ]] && [[ "$PXE_RECOVER_MODE" = "unattended" ]] ; then
    # If we have chosen for "unattended" recover mode then we also copy the
    # required pxe modules (and we assume that the PXE server run the same OS)
    # copy pxelinux.0 and friends
    # RHEL/SLES and friends
    PXELINUX_BIN=$( find_syslinux_file pxelinux.0 )
    if [[ -z "$PXELINUX_BIN" ]] ; then
        # perhaps Debian/Ubuntu and friends
        [[ -f /usr/lib/PXELINUX/pxelinux.0 ]] && PXELINUX_BIN=/usr/lib/PXELINUX/pxelinux.0
    fi
    if [[ ! -z "$PXELINUX_BIN" ]] ; then
        cp $v "$PXELINUX_BIN" $BUILD_DIR/tftpbootfs >&2
    fi
    syslinux_modules_dir=$( find_syslinux_modules_dir menu.c32 )
    [[ -z "$syslinux_modules_dir" ]] && syslinux_modules_dir=$(dirname $PXELINUX_BIN)
    cp $v $syslinux_modules_dir/ldlinux.c32 $BUILD_DIR/tftpbootfs >&2
    cp $v $syslinux_modules_dir/libcom32.c32 $BUILD_DIR/tftpbootfs >&2
    cp $v $syslinux_modules_dir/libutil.c32 $BUILD_DIR/tftpbootfs >&2
    cp $v $syslinux_modules_dir/menu.c32 $BUILD_DIR/tftpbootfs >&2
    cp $v $syslinux_modules_dir/chain.c32 $BUILD_DIR/tftpbootfs >&2
    cp $v $syslinux_modules_dir/hdt.c32 $BUILD_DIR/tftpbootfs >&2
    cp $v $syslinux_modules_dir/reboot.c32 $BUILD_DIR/tftpbootfs >&2
    if [[ -r "$syslinux_modules_dir/poweroff.com" ]] ; then
        cp $v $syslinux_modules_dir/poweroff.com $BUILD_DIR/tftpbootfs >&2
    elif [[ -r "$syslinux_modules_dir/poweroff.c32" ]] ; then
        cp $v $syslinux_modules_dir/poweroff.c32 $BUILD_DIR/tftpbootfs >&2
    fi
    chmod 644 $BUILD_DIR/tftpbootfs/*.c32
    chmod 644 $BUILD_DIR/tftpbootfs/*.0
fi


if [[ ! -z "$PXE_TFTP_URL" ]] ; then
    LogPrint "Copied kernel+initrd $( du -shc $KERNEL_FILE "$TMP_DIR/$REAR_INITRD_FILENAME" | tail -n 1 | tr -s "\t " " " | cut -d " " -f 1 ) to $PXE_TFTP_URL/$OUTPUT_PREFIX_PXE"
    umount_url $PXE_TFTP_URL $BUILD_DIR/tftpbootfs
else
    # legacy way PXE_TFTP_PATH
    LogPrint "Copied kernel+initrd $( du -shc $KERNEL_FILE "$TMP_DIR/$REAR_INITRD_FILENAME" | tail -n 1 | tr -s "\t " " " | cut -d " " -f 1 ) to $PXE_TFTP_PATH"
    # Add to result files
    RESULT_FILES+=( "$PXE_TFTP_LOCAL_PATH/$PXE_KERNEL" "$PXE_TFTP_LOCAL_PATH/$PXE_INITRD" "$PXE_TFTP_LOCAL_PATH/$PXE_MESSAGE" )
fi

# vim: set et ts=4 sw=4
