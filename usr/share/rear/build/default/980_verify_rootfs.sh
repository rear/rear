# Test that the ROOTFS_DIR contains a usable system
# i.e. test that the ReaR recovery system will be usable
# to avoid issues like https://github.com/rear/rear/issues/1494

# In case the filesystem that contains the ROOTFS_DIR is mounted 'noexec' we must skip the 'chroot' tests.
# The filesystem_name function in linux-functions.sh returns the mountpoint (not a filesystem name like 'ext4'):
rootfs_dir_fs_mountpoint=$( filesystem_name $ROOTFS_DIR )

if grep -qE '^\S+ '$rootfs_dir_fs_mountpoint' \S+ \S*\bnoexec\b\S* ' /proc/mounts ; then
    LogPrint "Cannot test if the ReaR recovery system is usable because $rootfs_dir_fs_mountpoint is mounted 'noexec'"
    Log "We cannot run tests inside the ReaR recovery system by using 'chroot' because
we need the 'exec' option set to the filesystem. One way to achieve this is
by doing: mount -o remount,exec $rootfs_dir_fs_mountpoint"
    return
fi

# The bash test ensures that we have a working bash in the ReaR recovery system:
if ! chroot $ROOTFS_DIR /bin/bash -c true ; then
    KEEP_BUILD_DIR=1
    BugError "ReaR recovery system in '$ROOTFS_DIR' is broken: 'bash -c true' failed"
fi

# The ldd test ensures that for dynamically linked executables the required libraries are there.
# The ldd test runs after the bash test because /bin/ldd is a bash script.
# First test is 'ldd /bin/bash' to ensure 'ldd' works:
if ! chroot $ROOTFS_DIR /bin/ldd /bin/bash 1>&2 ; then
    KEEP_BUILD_DIR=1
    BugError "ReaR recovery system in '$ROOTFS_DIR' is broken: 'ldd /bin/bash' failed"
fi
# Now test each binary (except links) with ldd and look for 'not found' libraries.
# In case of 'not found' libraries for dynamically linked executables ldd returns zero exit code.
# When running ldd for a file that is 'not a dynamic executable' ldd returns non-zero exit code.
local binary=""
local broken_binaries=""
pushd $ROOTFS_DIR 1>&2
for binary in $( find bin/ -type f ) ; do
    if chroot $ROOTFS_DIR /bin/ldd $binary | grep 'not found' ; then
        echo "library missing for $binary"
        broken_binaries="$broken_binaries $( basename $binary )"
    fi
done 1>&2
popd 1>&2
if contains_visible_char "$broken_binaries" ; then
    KEEP_BUILD_DIR=1
    # Usually it should be no BugError when there are libraries missing for particular binaries because probably
    # the reason is that the user added only the plain binaries with COPY_AS_IS (instead of using REQUIRED_PROGS)
    # so that usually it should be a user Error when there are libraries missing for particular binaries:
    Error "ReaR recovery system in '$ROOTFS_DIR' not usable:$broken_binaries require additional libraries, check $RUNTIME_LOGFILE for details"
fi

