# 420_copy_firmware_files.sh
#
# Copy firmware files to the rescue/recovery system.

# The special value FIRMWARE_FILES=( 'no' ) or any value that
# is recognized as 'no' by the is_false function enforces that
# no files from the /lib*/firmware/ directories get included
# in the rescue/recovery system:
if is_false "$FIRMWARE_FILES" ; then
    LogPrint "Omit copying files in /lib*/firmware/ (FIRMWARE_FILES='$FIRMWARE_FILES')"
    return
fi

# COPY_MODULES=( all_modules ) is set when MODULES contains 'all_modules'
# in the previous 400_copy_modules.sh script and then usually all firmware files
# in the /lib*/firmware/ directories should get included in the rescue/recovery system:
if IsInArray "all_modules" "${COPY_MODULES[@]}" ; then
    # On certain architectures like ppc64 or ppc64le FIRMWARE_FILES could be set different
    # (cf. the conf/Linux-ppc64.conf and conf/Linux-ppc64le.conf scripts)
    # or FIRMWARE_FILES was specified by the user so do not overwrite that here:
    test "${FIRMWARE_FILES[*]}" || FIRMWARE_FILES=( 'yes' )
fi

# The special value FIRMWARE_FILES=( 'yes' ) or any value that
# is recognized as 'yes' by the is_true function enforces that
# all files from the /lib*/firmware/ directories get included
# in the rescue/recovery system:
if is_true "$FIRMWARE_FILES" ; then
    LogPrint "Copying all files in /lib*/firmware/"
    # Use a simple 'cp -a' for this case to be safe against possible issues
    # with the more complicated 'find ... | xargs cp' method below.
    # The '--parents' is needed to get the '/lib*/' directory in the copy.
    # It is crucial to append to /dev/$DISPENSABLE_OUTPUT_DEV (cf. 'Print' in lib/_framework-setup-and-functions.sh):
    cp $verbose -t $ROOTFS_DIR -a --parents /lib*/firmware 2>>/dev/$DISPENSABLE_OUTPUT_DEV 1>&2
    return
fi

# FIRMWARE_FILES is set but neither 'yes' nor 'no'
# so the user has specified which FIRMWARE_FILES should be copied.
# In this case copy exactly what the user has specified:
if test "${FIRMWARE_FILES[*]}" ; then
    LogPrint "Copying files from /lib*/firmware/ that match ${FIRMWARE_FILES[@]}"
    for find_ipath_pattern in "${FIRMWARE_FILES[@]}" ; do
        # No need to test if find_ipath_pattern is empty because 'find' does not find anything with empty '-ipath'.
        # The 'cp --parents' does not copy empty directories which should not matter (a directory without a firmware file is useless) and
        # it may report "cp: omitting directory ..." so that this particular stderr message is filtered out because it is meaningless here
        # and 'cp -L' ensures that when during 'find -ipath' only a symbolic link name matches, the actual firmware file gets copied
        # (note that 'find -L' would not work because it still outputs the symbolic link name).
        # Ignore errors in this complicated case because it is in practice impossible to decide what errors should be fatal.
        # For example when 'find' does not find anything for a find_ipath_pattern 'cp' fails with "cp: missing file operand"
        # and 'grep -v foo' results exit code 1 if 'foo' is in all input lines (i.e. when 'grep -v' results no output):
        find /lib*/firmware -ipath "$find_ipath_pattern" | xargs cp $verbose -t $ROOTFS_DIR -p -L --parents 2>&1 | grep -v 'omitting directory' 1>&2 || true
    done
    return
fi

# Finally the fallback case:
# FIRMWARE_FILES is not specified and MODULES is not the default 'all_modules'
# for example when MODULES=( 'loaded_modules' ) and FIRMWARE_FILES is empty.
# COPY_MODULES contains the kernel module names of the modules
# which should have been copied in the previous 400_copy_modules.sh script.
# Automatically also copy the matching firmware files here, see
# https://github.com/rear/rear/issues/3551
LogPrint "Copying firmware files that belong to the copied kernel modules (FIRMWARE_FILES not specified)"
firmware_partial_filenames=$( modinfo -k $KERNEL_VERSION -F firmware "${COPY_MODULES[@]}" )
for firmware_partial_filename in $firmware_partial_filenames ; do
    # For example the command "modinfo -F firmware amdgpu" may show
    # amdgpu/cyan_skillfish_gpu_info.bin
    # amdgpu/navi12_gpu_info.bin
    # ...
    # The actual firmware files could be none for amdgpu/cyan_skillfish_gpu_info.bin
    # because firmware files which are listed by modinfo may not exist on the system
    # and for amdgpu/navi12_gpu_info.bin the actual firmware files could be
    # /lib/firmware/amdgpu/navi12_gpu_info.bin.xz
    # so what is listed by modinfo is only a part of the actual firmware file
    # without leading path and without suffix so we need to find the actual firmware file:
    firmware_complete_filename=$( find /lib*/firmware -path "*$firmware_partial_filename*" )
    test -r "$firmware_complete_filename" || continue
    cp $verbose -t $ROOTFS_DIR -p -L --parents $firmware_complete_filename
done

