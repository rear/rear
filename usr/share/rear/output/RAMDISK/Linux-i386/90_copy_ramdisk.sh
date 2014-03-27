### Copy the kernel and the initramfs to the location given in OUTPUT_URL

if [[ -z "$OUTPUT_URL" ]] ; then
    OUTPUT_URL=file://$VAR_DIR/output
    Log "No OUTPUT_URL defined. Using default location $OUTPUT_URL."
fi

local scheme=$(url_scheme $OUTPUT_URL)
local path=$(url_path $OUTPUT_URL)

if [[ "$BACKUP" == "NETFS" ]] ; then
    cp $v -pLf $KERNEL_FILE $TMP_DIR/kernel-$RAMDISK_SUFFIX >&2
    cp $v -pLf $TMP_DIR/initrd.cgz $TMP_DIR/initramfs-$RAMDISK_SUFFIX.img >&2

    # NETFS will copy things for us
    RESULT_FILES=( "${RESULT_FILES[@]}" $TMP_DIR/kernel-$RAMDISK_SUFFIX $TMP_DIR/initramfs-$RAMDISK_SUFFIX.img )
    return
fi

case "$scheme" in
    (tape)
        # does not make sense for tape
        return 0
        ;;
    (file)
        LogPrint "Transferring kernel and initramfs to $path"
        mkdir -p $v $path >&2
        cp $v -pLf $KERNEL_FILE $path/kernel-$RAMDISK_SUFFIX >&2
        cp $v -pLf $TMP_DIR/initrd.cgz $path/initramfs-$RAMDISK_SUFFIX.img >&2
        ;;
    (nfs|cifs|usb|davfs)
        LogPrint "Transferring kernel and initramfs to $OUTPUT_URL"
        mkdir -p $v $BUILD_DIR/outputfs/$NETFS_PREFIX/ >&2
        cp $v -pLf $KERNEL_FILE $BUILD_DIR/outputfs/$NETFS_PREFIX/kernel-$RAMDISK_SUFFIX >&2
        cp $v -pLf $TMP_DIR/initrd.cgz $BUILD_DIR/outputfs/$NETFS_PREFIX/initramfs-$RAMDISK_SUFFIX.img >&2
        ;;
    (fish|ftp|ftps|hftp|http|https|sftp)
        LogPrint "Transferring kernel and initramfs to $OUTPUT_URL"
        lftp -c "open $OUTPUT_URL; mkdir $path; mput -O $path $KERNEL_FILE"
        StopIfError "Problem transferring kernel to $OUTPUT_URL"
        lftp -c "open $OUTPUT_URL; mkdir $path; mput -O $path $TMP_DIR/initrd.cgz"
        StopIfError "Problem transferring ramdisk to $OUTPUT_URL"
        ;;
    (rsync)
        LogPrint "Transferring kernel and initramfs to $OUTPUT_URL"
        rsync -a $v "$KERNEL_FILE" "$OUTPUT_URL"
        StopIfError "Problem transferring kernel to $OUTPUT_URL"
        rsync -a $v "$TMP_DIR/initrd.cgz" "$OUTPUT_URL"
        StopIfError "Problem transferring ramdisk to $OUTPUT_URL"
        ;;
    (*) BugError "Support for $scheme is not implemented yet.";;
esac
