# 420_copy_firmware_files.sh
#
# copy firmware files to the rescue/recovery system.

# The special value FIRMWARE_FILES=( 'no' ) or any value that
# is recognized as 'no' by the is_false function enforces that
# no files from the /lib*/firmware/ directories get included
# in the rescue/recovery system:
is_false "$FIRMWARE_FILES" && return

# The special value FIRMWARE_FILES=( 'yes' ) or any value that
# is recognized as 'yes' by the is_true function enforces that
# all files from the /lib*/firmware/ directories get included
# in the rescue/recovery system:
is_true "$FIRMWARE_FILES" && FIRMWARE_FILES=( '*' )

# The by default empty FIRMWARE_FILES array means that
# usually all files in the /lib*/firmware/ directories
# get included in the rescue/recovery system but on certain
# architectures like ppc64 or ppc64le FIRMWARE_FILES could be set different
# (cf. the conf/Linux-ppc64.conf and conf/Linux-ppc64le.conf scripts)
# or FIRMWARE_FILES was specified by the user:
test "${FIRMWARE_FILES[*]}" || FIRMWARE_FILES=( '*' )

# Inform the user:
LogPrint "Copying firmware files from /lib*/firmware/ that match ${FIRMWARE_FILES[@]}"

# The actual work:
for find_ipath_pattern in "${FIRMWARE_FILES[@]}" ; do
    # No need to test if find_ipath_pattern is empty because 'find' does not find anything with empty '-ipath'.
    # The 'cp --parents' does not copy empty directories and complains about it with "cp: omitting directory ..."
    # so that this particular stderr message is filtered out because it is useless here:
    find /lib*/firmware -ipath "$find_ipath_pattern" | xargs cp -t $ROOTFS_DIR -p --parents 2>&1 | grep -v 'omitting directory' 1>&2
done

