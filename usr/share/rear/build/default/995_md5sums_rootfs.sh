
# build/default/995_md5sums_rootfs.sh
#
# Create md5sums for all regular files in ROOTFS_DIR
# and store the result in ROOTFS_DIR as md5sums.txt
# so that in the recovery system one can test via
#   pushd / ; md5sum --quiet --check md5sums.txt ; popd
# if the regular files in the recovery system are intact.
# That test must happen first of all during recovery system startup
# before files may get changed by recovery system startup scripts
# see skel/default/etc/scripts/system-setup for details.
# The reason behind is that there could be errors during loading/unpacking
# of the initrd/initramfs which are reported (if one knows how to look for them)
# but at least some errors do not abort the boot process so that
# it could happen that files in the recovery system are corrupt
# but the user may not notice the actual error and get any kind
# of inexplicable errors later when using the recovery system,
# see https://github.com/rear/rear/issues/1859
# and https://github.com/rear/rear/issues/1724

# Skip that if the user had specified to exclude md5sums for all files:
test "all" = "$EXCLUDE_MD5SUM_VERIFICATION" && return || Log "Creating md5sums for regular files in $ROOTFS_DIR"

local md5sums_file="md5sums.txt"
# Careful in case of 'return' after 'pushd' (must call the matching 'popd' before 'return'):
pushd $ROOTFS_DIR 1>&2
    cat /dev/null >$md5sums_file
    # Do not provide a md5sums.txt in the recovery system if it was not successfully created here.
    # Exclude the md5sums.txt file itself and all .gitignore files here in any case.
    # Also exclude all regular files in /dev/ (device nodes get already excluded by 'find -type f')
    # because sometimes it could happen that there are regular files in /dev/ in ROOTFS_DIR
    # which won't get copied into the recovery system so that those regular files in /dev/
    # are missing when etc/scripts/system-setup tries to verify their md5sums, for example
    # see https://github.com/rear/rear/issues/1883#issuecomment-409875733
    # and https://github.com/rear/rear/issues/1891#issue-347952166
    # that both read (excerpts):
    #   md5sum: ./dev/.SRC-Semaphore: No such file or directory
    #   ./dev/.SRC-Semaphore: FAILED open or read
    # where /dev/.SRC-Semaphore seems to be related to IBM Reliable Scalable Cluster Technology (RSCT)
    # see http://www-01.ibm.com/support/docview.wss?uid=isg1IV35736
    # Excluding particular files from being verified during recovery system startup
    # happens via EXCLUDE_MD5SUM_VERIFICATION in skel/default/etc/scripts/system-setup
    find . -xdev -type f | egrep -v '/md5sums\.txt|/\.gitignore|/dev/' | xargs md5sum >>$md5sums_file || cat /dev/null >$md5sums_file
popd 1>&2

