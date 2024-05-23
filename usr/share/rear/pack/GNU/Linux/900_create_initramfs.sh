# 900_create_initramfs.sh
#
# create initramfs for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# The REAR_INITRD_FILENAME is needed in various subsequent scripts that install the bootloader
# of the Relax-and-Recover recovery/rescue system during the subsequent 'output' stage.
# REAR_INITRD_FILENAME contains the filename (i.e. basename) of ReaR's own initramfs/initrd
# that contains the files of the Relax-and-Recover recovery/rescue system.
# In contrast a variable that contains the filename of the initramfs/initrd of the system
# where "rear mkbackup" runs would have to be named like SYSTEM_INITRD_FILENAME and/or
# where "rear recover" runs like TARGET_SYSTEM_INITRD_FILENAME (cf. TARGET_FS_ROOT).

# Create initrd.cgz with gzip default compression by default and also as fallback
# (no need to error out here if REAR_INITRD_COMPRESSION has an invalid value)

# for zvm name override -  see REAR_INITRD_FILENAME override for lz4, xz and gz compression below
# -------------------------------------------------------------------------------------------------
# s390 optional naming override of initrd and kernel to match the s390 filesytem naming conventions
# on s390a there is an option to name the initrd and kernel in the form of
# file name on s390 are in the form of name type mode
# the name is the userid or vm name and the type is initrd or kernel
# if the vm name (cp q userid) is HOSTA then the files written will be HOSTA kernel and HOSTA initrd
# vars needed:
# ZVM_NAMING      - set in local.conf, if Y then enable naming override
# ZVM_KERNEL_NAME - keeps track of kernel name in results array
# ARCH            - override only if ARCH is Linux-s390
# 
# initrd name override is handled in 900_create_initramfs.sh
# kernel name override is handled in 400_guess_kernel.sh
# kernel name override is handled in 950_copy_result_files.sh

if [ "$ARCH" == "Linux-s390" ] ; then
   VM_UID=$(vmcp q userid |awk '{ print $1 }')

   if [[ -z $VM_UID && "$ZVM_NAMING" == "Y" ]] ; then
      Error "VM UID is not set, VM UID is set from call to vmcp.  Please make sure vmcp is available and 'vmcp q userid' returns VM ID"
   fi      
fi

pushd "$ROOTFS_DIR" >/dev/null
start_seconds=$( date +%s )
case "$REAR_INITRD_COMPRESSION" in
    (lz4)
        # Create initrd.lz4 with lz4 default -1 compression (fast speed but less compression)
        # -l is needed to make initramfs boot, this compresses using Legacy format (Linux kernel compression)
        if [[ "$ZVM_NAMING" == "Y" && "$ARCH" == "Linux-s390" ]] ; then
            REAR_INITRD_FILENAME=$VM_UID".initrd"
        else
            REAR_INITRD_FILENAME="initrd.lz4"
        fi
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with lz4 compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | lz4 -l > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with lz4 compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
    (lzma)
        # Create initrd.xz with xz and use the lzma compression, see https://github.com/rear/rear/issues/1142
        if [[ "$ZVM_NAMING" == "Y" && "$ARCH" == "Linux-s390" ]] ; then
            REAR_INITRD_FILENAME=$VM_UID".initrd"
        else
            REAR_INITRD_FILENAME="initrd.xz"
        fi
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with xz lzma compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | xz --format=lzma --compress --stdout > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with xz lzma compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
    (fast)
        # Create initrd.cgz with gzip --fast compression (fast speed but less compression)
        if [[ "$ZVM_NAMING" == "Y" && "$ARCH" == "Linux-s390" ]] ; then
            REAR_INITRD_FILENAME=$VM_UID".initrd"
        else
            REAR_INITRD_FILENAME="initrd.cgz"
        fi
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with gzip fast compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | gzip --fast > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with gzip fast compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
    (best)
        # Create initrd.cgz with gzip --best compression (best compression but slow speed)
        if [[ "$ZVM_NAMING" == "Y" && "$ARCH" == "Linux-s390" ]] ; then
            REAR_INITRD_FILENAME=$VM_UID".initrd"
        else
            REAR_INITRD_FILENAME="initrd.cgz"
        fi
        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with gzip best compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | gzip --best > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with gzip best compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
    (*)
        if [[ "$ZVM_NAMING" == "Y" && "$ARCH" == "Linux-s390" ]] ; then
            REAR_INITRD_FILENAME=$VM_UID".initrd"
        else
            REAR_INITRD_FILENAME="initrd.cgz"
        fi

        LogPrint "Creating recovery/rescue system initramfs/initrd $REAR_INITRD_FILENAME with gzip default compression"
        if find . ! -name "*~" | cpio -H newc --create --quiet | gzip > "$TMP_DIR/$REAR_INITRD_FILENAME" ; then
            needed_seconds=$(( $( date +%s ) - start_seconds ))
            LogPrint "Created $REAR_INITRD_FILENAME with gzip default compression ($( stat -c%s $TMP_DIR/$REAR_INITRD_FILENAME ) bytes) in $needed_seconds seconds"
        else
            # No need to clean up things (like 'popd') because Error exits directly:
            Error "Failed to create recovery/rescue system $REAR_INITRD_FILENAME"
        fi
        ;;
esac

# Only root should be allowed to access the initrd
# because the ReaR recovery system can contain secrets
# cf. https://github.com/rear/rear/issues/3122
test -s "$TMP_DIR/$REAR_INITRD_FILENAME" && chmod 0600 "$TMP_DIR/$REAR_INITRD_FILENAME"

popd >/dev/null

# On POWER architecture there could be an initrd size limit depending on the boot method
# which is 128 MiB minus some MiBs for IBM's prep boot service data
# so in practice what is left for the initrd is about 120 MiB or even less,
# cf. the somewhat related IBM article
# https://www.ibm.com/support/pages/system-boot-ends-grub-out-memory-oom
# which talks about other limit values but it describes the general idea behind.
# This article tells that one gets an "out of memory" error when the limit is exceeded
# but in practice it also happens that the kernel starts up but fails with something like
# "Kernel panic - not syncing: VFS: Unable to mount root fs ..."
# cf. the 'boot.log' attachment in https://github.com/rear/rear/issues/3189
# and then it is almost impossible to imagine that the root cause of such a kernel panic
# is a too big initrd.
# So to be a bit more on the safe side we at least tell the user here
# when the initrd is bigger than 100 MiB that this may cause a boot failure:
if test "$ARCH" = "Linux-ppc64" || test "$ARCH" = "Linux-ppc64le" ; then
    initrd_bytes=$( stat -L -c '%s' "$TMP_DIR/$REAR_INITRD_FILENAME" )
    # Continue "bona fide" if the initrd size could not be determined (assume the initrd size is OK):
    if is_positive_integer $initrd_bytes ; then
        initrd_MiB=$( mathlib_calculate "$initrd_bytes / 1048576" )
        # 100 MiB = 100 * 1 MiB = 100 * 1048576 bytes = 104857600 bytes
        if test $initrd_bytes -ge 104857600 ; then
            LogPrintError "On POWER architecture booting may fail when the initrd is too big (initrd size is $initrd_MiB MiB)"
            if ! test "$REAR_INITRD_COMPRESSION" = "lzma" ; then
                # For example an initrd with 120 MB with default gzip compression became only 77 MB with lzma
                # but whith lzma compression "rear mkrescue" needed 2 minutes more time in this particular case,
                # cf. https://github.com/rear/rear/issues/3189#issuecomment-2079794186
                LogPrintError "Consider better (but slower) initrd compression with REAR_INITRD_COMPRESSION='lzma'"
            fi
            if test "$BACKUP" = "TSM" ; then
                if ! test "${COPY_AS_IS_EXCLUDE_TSM[*]}" ; then
                    # See also https://github.com/rear/rear/issues/3189#issuecomment-2079794186
                    # and https://github.com/rear/rear/issues/3189#issuecomment-2093032268
                    LogPrintError "Consider using COPY_AS_IS_EXCLUDE_TSM to get a slim TSM client in the initrd"
                fi
            fi
        fi
    fi
fi

