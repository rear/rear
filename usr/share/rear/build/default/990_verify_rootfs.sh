#
# Test that the ROOTFS_DIR contains a usable system
# i.e. test that the ReaR recovery system will be usable
# to avoid issues like https://github.com/rear/rear/issues/1494

LogPrint "Testing that the recovery system in $ROOTFS_DIR contains a usable system"

if test "$KEEP_BUILD_DIR" = "errors"; then
    local keep_build_dir_on_errors=1
else
    # KEEP_BUILD_DIR does not say to keep it on errors
    # - effective value depends on whether we are running interactively
    if tty -s ; then
        local keep_build_dir_on_errors=1
    else
        local keep_build_dir_on_errors=0
    fi
fi

function keep_build_dir() {
    if ! is_true "$KEEP_BUILD_DIR" && ! is_false "$KEEP_BUILD_DIR"; then
        # is either empty or equal to "errors" ... or some garbage value
        local orig_keep_build_dir="$KEEP_BUILD_DIR"
        KEEP_BUILD_DIR="${keep_build_dir_on_errors}"
    fi
    if is_true "$KEEP_BUILD_DIR" ; then
        LogPrintError "Build area kept for investigation in $BUILD_DIR, remove it when not needed"
    elif ! is_false "$orig_keep_build_dir" ; then
        # if users disabled preserving the build dir explicitly, let's not bother them with messages
        LogPrintError "Build area $BUILD_DIR will be removed"
        LogPrintError "To preserve it for investigation set KEEP_BUILD_DIR=errors or run ReaR with -d"
    fi
}

# In case the filesystem that contains the ROOTFS_DIR is mounted 'noexec' we cannot do the 'chroot' tests.
# The filesystem_name function in linux-functions.sh returns the mountpoint (not a filesystem name like 'ext4'):
local rootfs_dir_fs_mountpoint=$( filesystem_name $ROOTFS_DIR )
if grep -qE '^\S+ '$rootfs_dir_fs_mountpoint' \S+ \S*\bnoexec\b\S* ' /proc/mounts ; then
    # Intentionally failing here with Error to make it mandatory for ReaR to really check the rescue image.
    # It is much more important to guarantee a runnable rescue image than to support noexec environments,
    # cf. https://github.com/rear/rear/pull/1514#discussion_r140752346
    Error "Cannot test if the ReaR recovery system is usable because $rootfs_dir_fs_mountpoint is mounted 'noexec'"
fi

# The bash test ensures that we have a working bash in the ReaR recovery system:
if ! chroot $ROOTFS_DIR /bin/bash -c true ; then
    keep_build_dir
    BugError "ReaR recovery system in '$ROOTFS_DIR' is broken: 'bash -c true' failed"
fi

# The ldd test ensures that for dynamically linked executables the required libraries are there.
# The ldd test runs after the bash test because /bin/ldd is a bash script.
# First test is 'ldd /bin/bash' to ensure 'ldd' works:
Log "Testing 'ldd /bin/bash' to ensure 'ldd' works for the subsequent 'ldd' tests within the recovery system"
if ! chroot $ROOTFS_DIR /bin/ldd /bin/bash 1>&2 ; then
    keep_build_dir
    BugError "ReaR recovery system in '$ROOTFS_DIR' is broken: 'ldd /bin/bash' failed"
fi

# Now test each binary (except links) with ldd and look for 'not found' libraries.
# In case of 'not found' libraries for dynamically linked executables ldd returns zero exit code.
# When running ldd for a file that is 'not a dynamic executable' ldd returns non-zero exit code.
# FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
# see https://github.com/rear/rear/pull/1514#discussion_r141031975
# and for the general issue see https://github.com/rear/rear/issues/1372
Log "Testing each binary (except links) with ldd and look for 'not found' libraries within the recovery system"
local binary=""
local broken_binaries=""
# Third-party backup tools may use LD_LIBRARY_PATH to find their libraries
# so that for testing such third-party backup tools we must also use
# their special LD_LIBRARY_PATH here:
local old_LD_LIBRARY_PATH
# Save LD_LIBRARY_PATH only if one is already set:
test $LD_LIBRARY_PATH && old_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
if test "$BACKUP" = "TSM" ; then
    # Use a TSM-specific LD_LIBRARY_PATH to find TSM libraries
    # see https://github.com/rear/rear/issues/1533
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$TSM_LD_LIBRARY_PATH
fi
if test "$BACKUP" = "SESAM" ; then
    # Use a SEP sesam-specific LD_LIBRARY_PATH to find sesam client
    # related libraries
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$SESAM_LD_LIBRARY_PATH
fi
if test "$BACKUP" = "NBU" ; then
    # Use a NBU-specific LD_LIBRARY_PATH to find NBU libraries
    # see https://github.com/rear/rear/issues/1974
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$NBU_LD_LIBRARY_PATH
fi
# Actually test all binaries for 'not found' libraries.
# Find all binaries and libraries also e.g. those that are copied via COPY_AS_IS into other paths:
for binary in $( find $ROOTFS_DIR -type f -executable -printf '/%P\n' ) ; do
    # Skip the ldd test for kernel modules because in general running ldd on kernel modules does not make sense
    # and sometimes running ldd on kernel modules causes needless errors because sometimes that segfaults
    # which results false alarm "ldd: exited with unknown exit code (139)" messages ( 139 - 128 = 11 = SIGSEGV )
    # cf. https://github.com/rear/rear/issues/2177 which also shows that sometimes kernel modules could be
    # not only in the usual directory /lib/modules/ but also e.g. in /usr/lib/modules/
    # so we 'grep' for '/lib/modules/' anywhere in the full path of the binary:
    grep -q "/lib/modules/" <<<"$binary" && continue
    # In order to handle relative paths, we 'cd' to the directory containing $binary before running ldd.
    # In particular third-party backup tools may have shared object dependencies with relative paths.
    # For an example see https://github.com/rear/rear/pull/1560#issuecomment-343504359 that reads (excerpt):
    #   # ldd /opt/fdrupstream/uscmd1
    #       ...
    #       libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f8a7c449000)
    #       ./bin/ioOptimizer.so => not found
    #       libc.so.6 => /lib64/libc.so.6 (0x00007f8a7b52d000)
    #       ...
    #   # cd /opt/fdrupstream
    #   # ldd uscmd1
    #       ...
    #       libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f6657ac5000)
    #       ./bin/ioOptimizer.so (0x00007f665747d000)
    #       libc.so.6 => /lib64/libc.so.6 (0x00007f6656560000)
    #       ...
    # The login shell is there so that we can call commands as in a normal working shell,
    # cf. https://github.com/rear/rear/issues/862#issuecomment-274068914
    # Redirected stdin for login shell avoids motd welcome message, cf. https://github.com/rear/rear/issues/2120.
    chroot $ROOTFS_DIR /bin/bash --login -c "cd $( dirname $binary ) && ldd $binary" < /dev/null | grep -q 'not found' && broken_binaries="$broken_binaries $binary"
done
# Restore the LD_LIBRARY_PATH if it was saved above (i.e. when LD_LIBRARY_PATH had been set before)
# otherwise unset a possibly set LD_LIBRARY_PATH (i.e. when LD_LIBRARY_PATH had not been set before):
test $old_LD_LIBRARY_PATH && export LD_LIBRARY_PATH=$old_LD_LIBRARY_PATH || unset LD_LIBRARY_PATH

# Report binaries with 'not found' shared object dependencies:
local fatal_missing_library=""
if contains_visible_char "$broken_binaries" ; then
    LogPrintError "There are binaries or libraries in the ReaR recovery system that need additional libraries"
    local ldd_output=""
    for binary in $broken_binaries ; do
        # Only for programs (i.e. files in a .../bin/... or .../sbin/... directory) treat a missing library as fatal
        # unless specified when a 'not found' reported library is not fatal (when the 'ldd' test was false alarm):
        if grep -q '/[s]*bin/' <<<"$binary" ; then
            # With an empty NON_FATAL_BINARIES_WITH_MISSING_LIBRARY egrep -E '' would always match:
            if test "$NON_FATAL_BINARIES_WITH_MISSING_LIBRARY" ; then
                # A program with missing library is treated as fatal when it does not match the pattern:
                if grep -E -q "$NON_FATAL_BINARIES_WITH_MISSING_LIBRARY" <<<"$binary" ; then
                    LogPrintError "$binary requires additional libraries (specified as non-fatal)"
                else
                    LogPrintError "$binary requires additional libraries (fatal error)"
                    fatal_missing_library="yes"
                fi
            else
                LogPrintError "$binary requires additional libraries (fatal error)"
                fatal_missing_library="yes"
            fi
        else
            LogPrintError "$binary requires additional libraries"
        fi
        # Run the same ldd call as above but now keep its whole output:
        ldd_output="$( chroot $ROOTFS_DIR /bin/ldd $binary )"
        # Have the whole ldd output only in the log:
        Log "$ldd_output"
        # Show only the missing libraries to the user to not flood his screen with tons of other ldd output lines:
        PrintError "$( grep 'not found' <<<"$ldd_output" )"
    done
    LogPrintError "ReaR recovery system in '$ROOTFS_DIR' needs additional libraries, check $RUNTIME_LOGFILE for details"
    is_true "$fatal_missing_library" && keep_build_dir
fi

# Testing that each program in the PROGS array can be found as executable command within the recovery system
# provided the program exist on the original system:
Log "Testing that each program in the PROGS array can be found as executable command within the recovery system"
local program=""
local missing_programs=""
for program in "${PROGS[@]}" ; do
    # There are many programs in the PROGS array that may or may not exist on the original system
    # so that only those programs in the PROGS array that exist on the original system are tested:
    type $program || continue
    # Use the basename because the path within the recovery system is usually different compared to the path on the original system:
    program=$( basename $program )
    # Redirected stdin for login shell avoids motd welcome message, cf. https://github.com/rear/rear/issues/2120.
    chroot $ROOTFS_DIR /bin/bash --login -c "type $program" < /dev/null || missing_programs="$missing_programs $program"
done

# Report programs in the PROGS array that cannot be found as executable command within the recovery system:
if contains_visible_char "$missing_programs" ; then
    LogPrintError "There are programs that cannot be found as executable command in the ReaR recovery system"
    LogPrintError "$missing_programs"
    LogPrintError "ReaR recovery system in '$ROOTFS_DIR' lacks programs, check $RUNTIME_LOGFILE for details"
fi

# Testing that each program in the REQUIRED_PROGS array can be found as executable command within the recovery system:
Log "Testing that each program in the REQUIRED_PROGS array can be found as executable command within the recovery system"
local required_program=""
local missing_required_programs=""
local fatal_missing_program=""
for required_program in "${REQUIRED_PROGS[@]}" ; do
    # Use the basename because the path within the recovery system is usually different compared to the path on the original system:
    required_program=$( basename $required_program )
    # Redirected stdin for login shell avoids motd welcome message, cf. https://github.com/rear/rear/issues/2120.
    chroot $ROOTFS_DIR /bin/bash --login -c "type $required_program" < /dev/null || missing_required_programs="$missing_required_programs $required_program"
done
# Report programs in the REQUIRED_PROGS array that cannot be found as executable command within the recovery system:
if contains_visible_char "$missing_required_programs" ; then
    fatal_missing_program="yes"
    LogPrintError "Required programs cannot be found as executable command in the ReaR recovery system (bug error)"
    LogPrintError "$missing_required_programs"
    LogPrintError "ReaR recovery system in '$ROOTFS_DIR' lacks required programs, check $RUNTIME_LOGFILE for details"
    keep_build_dir
fi

# Finally after all tests had been done (so that the user gets all result messages) error out if needed:

# It is a BugError when at this stage required programs are missing in the recovery system
# because just before this script the script build/default/950_check_missing_programs.sh
# was run which errors out when there are missing required programs on the original system
# so that at this stage it means the required programs exist on the original system
# and something went wrong when making the recovery system:
is_true "$fatal_missing_program" && BugError "ReaR recovery system in '$ROOTFS_DIR' not usable (required programs are missing)"

# Usually it should be no BugError when there are libraries missing for particular binaries because probably
# the reason is that the user added only the plain binaries with COPY_AS_IS (instead of using REQUIRED_PROGS):
is_true "$fatal_missing_library" && Error "ReaR recovery system in '$ROOTFS_DIR' not usable (required libraries are missing)"

# Finish this script successfully:
true

