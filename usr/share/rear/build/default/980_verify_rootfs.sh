#
# Test that the ROOTFS_DIR contains a usable system
# i.e. test that the ReaR recovery system will be usable
# to avoid issues like https://github.com/rear/rear/issues/1494

# In case the filesystem that contains the ROOTFS_DIR is mounted 'noexec' we cannot do the 'chroot' tests.
# The filesystem_name function in linux-functions.sh returns the mountpoint (not a filesystem name like 'ext4'):
local rootfs_dir_fs_mountpoint=$( filesystem_name $ROOTFS_DIR )
if grep -qE '^\S+ '$rootfs_dir_fs_mountpoint' \S+ \S*\bnoexec\b\S* ' /proc/mounts ; then
    # Intentionally failing here with Error to make it mandatory for ReaR to really check the rescue image.
    # It is much more important to guarantee a runnable rescue image than to support noexec environments,
    # cf. https://github.com/rear/rear/pull/1514#discussion_r140752346
    Error "Cannot test if the ReaR recovery system is usable because $rootfs_dir_fs_mountpoint is mounted 'noexec'"
fi
Log "Testing that $ROOTFS_DIR contains a usable system"

# The bash test ensures that we have a working bash in the ReaR recovery system:
if ! chroot $ROOTFS_DIR /bin/bash -c true ; then
    KEEP_BUILD_DIR=1
    BugError "ReaR recovery system in '$ROOTFS_DIR' is broken: 'bash -c true' failed"
fi

# The ldd test ensures that for dynamically linked executables the required libraries are there.
# The ldd test runs after the bash test because /bin/ldd is a bash script.
# First test is 'ldd /bin/bash' to ensure 'ldd' works:
Log "Testing 'ldd /bin/bash' to ensure 'ldd' works for the subsequent 'ldd' tests"
if ! chroot $ROOTFS_DIR /bin/ldd /bin/bash 1>&2 ; then
    KEEP_BUILD_DIR=1
    BugError "ReaR recovery system in '$ROOTFS_DIR' is broken: 'ldd /bin/bash' failed"
fi
# Now test each binary (except links) with ldd and look for 'not found' libraries.
# In case of 'not found' libraries for dynamically linked executables ldd returns zero exit code.
# When running ldd for a file that is 'not a dynamic executable' ldd returns non-zero exit code.
local binary=""
local broken_binaries=""
# Catch all binaries and libraries also e.g. those that are copied via COPY_AS_IS into other paths.
# FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
# see https://github.com/rear/rear/pull/1514#discussion_r141031975
# and for the general issue see https://github.com/rear/rear/issues/1372
for binary in $( find $ROOTFS_DIR -type f -executable -printf '/%P\n' ) ; do
    chroot $ROOTFS_DIR /bin/ldd $binary | grep -q 'not found' && broken_binaries="$broken_binaries $binary"
done
if contains_visible_char "$broken_binaries" ; then
    LogPrintError "There are binaries or libraries in the ReaR recovery system that need additional libraries"
    KEEP_BUILD_DIR=1
    local fatal_missing_library=""
    local ldd_output=""
    for binary in $broken_binaries ; do
        # Only for programs (i.e. files in a .../bin/... or .../sbin/... directory) treat a missing library as fatal:
        grep -q '/[s]*bin/' <<<"$binary" && fatal_missing_library="yes"
        LogPrintError "$binary requires additional libraries"
        # Run the same ldd call as above but now keep its whole output:
        ldd_output="$( chroot $ROOTFS_DIR /bin/ldd $binary )"
        # Have the whole ldd output only in the log:
        Log "$ldd_output"
        # Show only the missing libraries to the user to not flood his screen with tons of other ldd output lines:
        PrintError "$( grep 'not found' <<<"$ldd_output" )"
    done
    # Usually it should be no BugError when there are libraries missing for particular binaries because probably
    # the reason is that the user added only the plain binaries with COPY_AS_IS (instead of using REQUIRED_PROGS):
    is_true "$fatal_missing_library" && Error "ReaR recovery system in '$ROOTFS_DIR' not usable"
    LogPrintError "ReaR recovery system in '$ROOTFS_DIR' needs additional libraries, check $RUNTIME_LOGFILE for details"
fi

