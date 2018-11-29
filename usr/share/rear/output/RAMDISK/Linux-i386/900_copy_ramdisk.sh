### Copy the kernel and the initramfs to the location given in OUTPUT_URL

if [[ -z "$OUTPUT_URL" ]] ; then
    OUTPUT_URL=file://$VAR_DIR/output
    Log "No OUTPUT_URL defined. Using default location $OUTPUT_URL."
fi

local scheme=$( url_scheme $OUTPUT_URL )
local path=$( url_path $OUTPUT_URL )

if [[ "$BACKUP" == "NETFS" ]] ; then
    LogPrint "Copying kernel and initramfs to NETFS location"
    cp $v -pLf $KERNEL_FILE $TMP_DIR/kernel-$RAMDISK_SUFFIX || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE'"
    cp $v -pLf $TMP_DIR/$REAR_INITRD_FILENAME $TMP_DIR/initramfs-$RAMDISK_SUFFIX.img || Error "Failed to copy initramfs '$REAR_INITRD_FILENAME'"
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
        mkdir -p $v $path || Error "Failed to create directory '$path'"
        cp $v -pLf $KERNEL_FILE $path/kernel-$RAMDISK_SUFFIX || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE' to $path"
        cp $v -pLf $TMP_DIR/$REAR_INITRD_FILENAME $path/initramfs-$RAMDISK_SUFFIX.img || Error "Failed to copy initramfs '$REAR_INITRD_FILENAME' to $path"
        ;;
    (nfs|cifs|usb|davfs)
        local target_directory="$BUILD_DIR/outputfs/$NETFS_PREFIX"
        LogPrint "Transferring kernel and initramfs to $OUTPUT_URL via $target_directory"
        mkdir -p $v $target_directory || Error "Failed to create directory '$target_directory' directory"
        cp $v -pLf $KERNEL_FILE $target_directory/kernel-$RAMDISK_SUFFIX || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE' to $target_directory"
        cp $v -pLf $TMP_DIR/$REAR_INITRD_FILENAME $target_directory/initramfs-$RAMDISK_SUFFIX.img || Error "Failed to copy initramfs '$REAR_INITRD_FILENAME' to $target_directory"
        ;;
    (fish|ftp|ftps|hftp|http|https|sftp)
        LogPrint "Transferring kernel and initramfs to $OUTPUT_URL"
        lftp -c "open $OUTPUT_URL; mkdir $path; mput -O $path $KERNEL_FILE" || Error "lftp failed to transfer KERNEL_FILE '$KERNEL_FILE to $OUTPUT_URL"
        lftp -c "open $OUTPUT_URL; mkdir $path; mput -O $path $TMP_DIR/$REAR_INITRD_FILENAME" || Error "lftp failed to transfer initramfs '$REAR_INITRD_FILENAME' to $OUTPUT_URL"
        ;;
    (rsync)
        LogPrint "Transferring kernel and initramfs to $OUTPUT_URL"
        rsync -a $v "$KERNEL_FILE" "$OUTPUT_URL" || Error "rsync failed to transfer KERNEL_FILE '$KERNEL_FILE to $OUTPUT_URL"
        rsync -a $v "$TMP_DIR/$REAR_INITRD_FILENAME" "$OUTPUT_URL" || Error "rsync failed to transfer initramfs '$REAR_INITRD_FILENAME' to $OUTPUT_URL"
        ;;
    (*) Error "Invalid scheme '$scheme' in '$OUTPUT_URL'."
        ;;
esac

