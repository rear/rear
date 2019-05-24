#
# output/RAMDISK/default/900_copy_ramdisk.sh
#
# Add kernel and the ReaR recovery system initrd to RESULT_FILES
# so that the subsequent output/default/950_copy_result_files.sh
# will copy them to the output location specified via OUTPUT_URL
# (if not specified OUTPUT_URL is inherited from BACKUP_URL).
#

local kernel_file="$KERNEL_FILE"
local initrd_file="$TMP_DIR/$REAR_INITRD_FILENAME"

# The 'test' intentionally also fails when RAMDISK_SUFFIX is more than one word
# because we do not want blanks in kernel or initrd file names:
if test $RAMDISK_SUFFIX ; then
    kernel_file="$TMP_DIR/kernel-$RAMDISK_SUFFIX"
    cp $v -pLf $KERNEL_FILE $kernel_file || Error "Failed to copy KERNEL_FILE '$KERNEL_FILE'"
    initrd_file="$TMP_DIR/initramfs-$RAMDISK_SUFFIX.img"
    cp $v -pLf $TMP_DIR/$REAR_INITRD_FILENAME $initrd_file || Error "Failed to copy initramfs '$REAR_INITRD_FILENAME'"
fi

DebugPrint "Adding $kernel_file and $initrd_file to RESULT_FILES"
RESULT_FILES+=( $kernel_file $initrd_file )

