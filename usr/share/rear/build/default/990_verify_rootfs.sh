#
# Test that the ROOTFS_DIR contains a usable system
# i.e. test that the ReaR recovery system will be usable
# to avoid issues like https://github.com/rear/rear/issues/1494

LogPrint "Testing that the ReaR recovery system in '$ROOTFS_DIR' contains a usable system"

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
        LogPrintError "Build area kept for investigation in '$BUILD_DIR', remove it when not needed"
    elif ! is_false "$orig_keep_build_dir" ; then
        # if users disabled preserving the build dir explicitly, let's not bother them with messages
        LogPrintError "Build area '$BUILD_DIR' will be removed"
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
# In case of 'not found' libraries for dynamically linked executables ldd returns zero exit code
# but that is the case that indicates an actual error in the ReaR recovery system so we grep for 'not found'.
# When running ldd for a file that is 'not a dynamic executable' ldd returns non-zero exit code
# which is not an error here because we run ldd for all executables (e.g. bash scripts like 'bin/rear')
# so we ignore when ldd returns non-zero exit code (and we also redirect its stderr to /dev/null).
# FIXME: The following code fails if file names contain characters from IFS (e.g. blanks),
# see https://github.com/rear/rear/pull/1514#discussion_r141031975
# and for the general issue see https://github.com/rear/rear/issues/1372
DebugPrint "Testing each binary with 'ldd' for 'not found' libraries within the ReaR recovery system"
local backup_tool_LD_LIBRARY_PATH=""
local binary=""
local binary_relpath=""
local broken_binary_LD_LIBRARY_PATH=""
local fatal_missing_library="no"
local ldd_output=""
local not_found_output=""
local not_found_library=""
local not_found_library_relpath=""
local junk=""
local actually_found_library=""
local actually_found_library_relpath=""
local actually_found_library_symlink_target=""
local actually_found_library_symlink_target_relpath=""
local actually_missing_libraries="no"
# Third-party backup tools may use LD_LIBRARY_PATH to find their libraries
# so that for testing such third-party backup tools we must also use their
# special LD_LIBRARY_PATH here, otherwise just use the default:
if contains_visible_char "$LD_LIBRARY_PATH_FOR_BACKUP_TOOL" ; then
    if test $LD_LIBRARY_PATH; then
        backup_tool_LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$LD_LIBRARY_PATH_FOR_BACKUP_TOOL"
    else
        backup_tool_LD_LIBRARY_PATH="$LD_LIBRARY_PATH_FOR_BACKUP_TOOL"
    fi
fi

# Actually test all binaries for 'not found' libraries.
# Find all binaries and libraries (in particular what is copied via COPY_AS_IS into arbitrary paths)
# so find what is a regular file and which is executable or its name is '*.so' or '*.so.[0-9]*'
# because libraries are not always set to be executable, cf. https://github.com/rear/rear/issues/2279
# Get what the full path is from within the recovery system i.e. without leading ROOTFS_DIR but with leading slash
# so e.g. /var/tmp/rear.XXXXXXXXXXXXXXX/rootfs/bin/parted is output as /bin/parted
# to use file names which are unambiguous within the recovery system:
for binary in $( find "$ROOTFS_DIR" -xdev -type f \( -executable -o -name '*.so' -o -name '*.so.[0-9]*' \) -printf '/%P\n' ) ; do
    # In user messages it is misleading to show the full path from within the recovery system without leading ROOTFS_DIR
    # e.g. show /bin/parted for what actually is /var/tmp/rear.XXXXXXXXXXXXXXX/rootfs/bin/parted
    # because for the user /bin/parted means the full path on his original system
    # but there is no /bin/parted on the original system because there it is /usr/sbin/parted
    # so to show files inside the recovery system to the user even without (the long) leading ROOTFS_DIR
    # we can show them to the user as relative path i.e. without leading slashes e.g. as bin/parted
    # when from the context it should be clear enough that a file inside the recovery system is meant
    # (extglob is set in usr/sbin/rear):
    binary_relpath="${binary##+(/)}"
    # Skip the ldd test for kernel modules because in general running ldd on kernel modules does not make sense
    # and sometimes running ldd on kernel modules causes needless errors because sometimes that segfaults
    # which results false alarm "ldd: exited with unknown exit code (139)" messages ( 139 - 128 = 11 = SIGSEGV )
    # cf. https://github.com/rear/rear/issues/2177 which also shows that sometimes kernel modules could be
    # not only in the usual directory /lib/modules/ but also e.g. in /usr/lib/modules/
    # so we 'grep' for '/lib/modules/' anywhere in the full path of the binary.
    # Skip the ldd test for firmware files where it also does not make sense.
    # Skip the ldd test for ReaR files (mainly bash scripts) where it does not make sense
    # (programs in the recovery system get all copied into /bin/ so it is /bin/rear)
    # cf. https://github.com/rear/rear/issues/2519#issuecomment-731196820
    grep -Eq "/lib/modules/|/lib.*/firmware/|$SHARE_DIR|/bin/rear$" <<<"$binary" && continue
    # Skip the ldd test for files that are not owned by a trusted user to mitigate possible ldd security issues
    # because some versions of ldd may directly execute the file (see "man ldd") as user 'root' here
    # cf. the RequiredSharedObjects code in usr/share/rear/lib/linux-functions.sh
    if test "$TRUSTED_FILE_OWNERS" ; then
        binary_owner_name="$( stat -c %U "$ROOTFS_DIR/$binary" )"
        if ! IsInArray "$binary_owner_name" "${TRUSTED_FILE_OWNERS[@]}" ; then
            # When the ldd test is skipped it can result non working executables in the recovery system
            # (i.e. executables without their required libraries that are not detected by this ldd test)
            # so we must ensure the user is notfied about those files where the ldd test is skipped:
            LogPrintError "Skipped ldd test for '$binary_relpath' (owner '$binary_owner_name' not in TRUSTED_FILE_OWNERS)"
            continue
        fi
    fi
    # In order to handle relative paths in the ldd output
    # we 'cd' to the directory containing $binary before running ldd.
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
    # Redirected stdin for login shell avoids motd welcome message, cf. https://github.com/rear/rear/issues/2120
    # and redirected stderr avoids ldd warnings in the log like "ldd: warning: you do not have execution permission for ..."
    # cf. https://blog.schlomo.schapiro.org/2015/04/warning-is-waste-of-my-time.html
    # The login shell in the ReaR recovery system should behave same as when 'root' has logged in into the recovery system.
    # Usually there is no LD_LIBRARY_PATH set when 'root' has logged in into the recovery system
    # (in particular there is nothing about LD_LIBRARY_PATH in usr/share/rear/skel/*).
    # First test the binary explicitly without any LD_LIBRARY_PATH setting inside the recovery system.
    # Continue testing the next binary if this one succeeded (i.e. when it has no 'not found' shared object dependency):
    chroot "$ROOTFS_DIR" /bin/bash --login -c "unset LD_LIBRARY_PATH && cd $( dirname $binary ) && ldd $binary" </dev/null 2>/dev/null | grep -q 'not found' || continue
    broken_binary_LD_LIBRARY_PATH=""
    Log "'ldd' shows 'not found' for $binary_relpath (no LD_LIBRARY_PATH set)"
    # Second test for the binary with same LD_LIBRARY_PATH as what is currently set while "rear mkrecue/mkbackup" is running.
    # The current LD_LIBRARY_PATH is explicitly set because the login shell in the recovery system has usually no LD_LIBRARY_PATH set.
    if test $LD_LIBRARY_PATH ; then
        Log "Another test for $binary_relpath with LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
        # Continue testing the next binary if this one succeeded (i.e. when it has no 'not found' shared object dependency):
        chroot "$ROOTFS_DIR" /bin/bash --login -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH && cd $( dirname $binary ) && ldd $binary" </dev/null 2>/dev/null | grep -q 'not found' || continue
        broken_binary_LD_LIBRARY_PATH=$LD_LIBRARY_PATH
        Log "'ldd' shows 'not found' for $binary_relpath (with LD_LIBRARY_PATH=$LD_LIBRARY_PATH)"
    fi
    # Third test for the binary with backup_tool_LD_LIBRARY_PATH if such a backup_tool_LD_LIBRARY_PATH was set above:
    if test $backup_tool_LD_LIBRARY_PATH ; then
        Log "Final test for $binary_relpath with LD_LIBRARY_PATH=$backup_tool_LD_LIBRARY_PATH"
        # Continue testing the next binary if this one succeeded (i.e. when it has no 'not found' shared object dependency):
        chroot "$ROOTFS_DIR" /bin/bash --login -c "export LD_LIBRARY_PATH=$backup_tool_LD_LIBRARY_PATH && cd $( dirname $binary ) && ldd $binary" </dev/null 2>/dev/null | grep -q 'not found' || continue
        broken_binary_LD_LIBRARY_PATH=$backup_tool_LD_LIBRARY_PATH
        Log "'ldd' shows 'not found' for $binary_relpath (with backup tool specific LD_LIBRARY_PATH=$backup_tool_LD_LIBRARY_PATH)"
    fi
    # At this point all tests had a 'not found' shared object dependency so the binary requires additional libraries
    # without LD_LIBRARY_PATH and with LD_LIBRARY_PATH and with backup tool specific LD_LIBRARY_PATH.
    # Only for programs (i.e. files in a .../bin/... or .../sbin/... directory) treat a missing library as fatal
    # unless specified when a 'not found' reported library is not fatal (when the 'ldd' test was false alarm):
    if grep -q '/[s]*bin/' <<<"$binary" ; then
        # With an empty NON_FATAL_BINARIES_WITH_MISSING_LIBRARY grep -E '' would always match:
        if test "$NON_FATAL_BINARIES_WITH_MISSING_LIBRARY" ; then
            # A program with missing library is treated as fatal when it does not match the pattern:
            if grep -E -q "$NON_FATAL_BINARIES_WITH_MISSING_LIBRARY" <<<"$binary" ; then
                LogPrint "$binary_relpath requires libraries where 'ldd' shows 'not found' (specified as non-fatal)"
            else
                LogPrint "$binary_relpath requires libraries where 'ldd' shows 'not found' (fatal error)"
                fatal_missing_library="yes"
            fi
        else
            LogPrint "$binary_relpath requires libraries where 'ldd' shows 'not found' (fatal by default)"
            fatal_missing_library="yes"
        fi
    else
        LogPrint "$binary_relpath requires libraries where 'ldd' shows 'not found'"
    fi
    # Run the same ldd call as above but now keep its whole stdout output.
    # The ldd call that results the final 'not found' shared object is the last of the above ldd calls that was run.
    # Run that ldd call with the same LD_LIBRARY_PATH setting as it was run above:
    if test $broken_binary_LD_LIBRARY_PATH ; then
        ldd_output="$( chroot "$ROOTFS_DIR" /bin/bash --login -c "export LD_LIBRARY_PATH=$broken_binary_LD_LIBRARY_PATH && cd $( dirname $binary ) && ldd $binary" </dev/null 2>/dev/null )"
    else
        ldd_output="$( chroot "$ROOTFS_DIR" /bin/bash --login -c "unset LD_LIBRARY_PATH && cd $( dirname $binary ) && ldd $binary" </dev/null 2>/dev/null )"
    fi
    # Have the whole ldd output only in the log:
    Log "$ldd_output"
    # For each 'not found' shared object (i.e. a shared object that was 'not found' by 'ldd')
    # check whether or not the shared object may exist nevertheless in the ReaR recovery system
    # and if yes, we may sufficiently safely assume things are OK in the ReaR recovery system
    # so we do not report it as missing to the user (for debugging we have all in the log)
    # cf. https://github.com/rear/rear/issues/3021#issuecomment-2165453757
    not_found_output="$( grep 'not found' <<<"$ldd_output" )"
    # not_found_output is a string of multiple lines (separated by \n) that look e.g. like
    #   libsystemd-shared-255.4-1.fc40.so => not found
    #   /path/to/library => not found
    while read not_found_library junk ; do
        # Show files from inside the recovery system to the user as relative path without leading slashes
        # (extglob is set in usr/sbin/rear):
        not_found_library_relpath="${not_found_library##+(/)}"
        # We prefer a simple grep pipe over dealing with 'find' and its -name versus -path options.
        # 'find' what the full path is from within the recovery system i.e. without leading ROOTFS_DIR but with leading slash
        # so e.g. /var/tmp/rear.XXXXXXXXXXXXXXX/rootfs/usr/lib64/libparted.so.2.0.1 is output as /usr/lib64/libparted.so.2.0.1
        # to ensure that grep matches e.g. when not_found_library="/usr/lib64/libparted.so.2.0.1" (has a leading slash).
        # Let grep match to the end of the line to avoid that falsely a prefix matches
        # e.g. when not_found_library="/usr/lib64/libparted.so.2" does not exist but /usr/lib64/libparted.so.2.0.1 exists:
        if actually_found_library="$( find "$ROOTFS_DIR" -xdev -printf '/%P\n' | grep "$not_found_library\$" )" ; then
            # Show files from inside the recovery system to the user as relative path without leading slashes (extglob is set in usr/sbin/rear):
            actually_found_library_relpath="${actually_found_library##+(/)}"
            # When what was found in the ReaR recovery system is not an actual library but a symlink
            # verify that its symlink target exist within the ReaR recovery system,
            # see https://github.com/rear/rear/issues/3414
            if test -L "$actually_found_library" ; then
                # "chroot $ROOTFS_DIR" is crucial to avoid a false positive result when the symlink is an absolute path
                # and a file with that absolute path exist on the original system but not within the ReaR recovery system.
                # 'readlink -e something' shows the filename when something is one or more files and exits with zero exit code
                # 'readlink -e something' shows the symlink target when something is a symlink and exits with zero exit code
                # 'readlink -e something' shows nothing when something is no file or a broken symlink and exits with exit code 1
                # 'readlink -e something' shows nothing on stdout but an error on stderr when something is empty and exits with exit code 1
                if actually_found_library_symlink_target="$( chroot "$ROOTFS_DIR" /bin/bash --login -c "readlink -e '$actually_found_library'" )" ; then
                    # Show files from inside the recovery system to the user as relative path without leading slashes (extglob is set in usr/sbin/rear):
                    actually_found_library_symlink_target_relpath="${actually_found_library_symlink_target##+(/)}"
                    LogPrint "$binary_relpath requires $not_found_library_relpath which exists as symlink $actually_found_library_relpath with target $actually_found_library_symlink_target_relpath"
                else
                    actually_missing_libraries="yes"
                    LogPrint "$binary_relpath requires $not_found_library_relpath which exists as dangling symlink $actually_found_library_relpath"
                fi
            else
                LogPrint "$binary_relpath requires $not_found_library_relpath which exists as $actually_found_library_relpath"
            fi
        else
            actually_missing_libraries="yes"
            # Show only the missing libraries to the user to not flood his screen with tons of other ldd output lines:
            LogPrintError "$binary_relpath requires $not_found_library_relpath which could not be found in the ReaR recovery system"
        fi
    done <<<"$not_found_output"
done
is_true $actually_missing_libraries && LogPrintError "ReaR recovery system in '$ROOTFS_DIR' needs additional libraries, check $RUNTIME_LOGFILE for details"
is_true $fatal_missing_library && keep_build_dir

# Testing that each program in the PROGS array can be found as executable command within the recovery system
# provided the program exist on the original system:
DebugPrint "Testing that the existing programs in the PROGS array can be found as executable command within the ReaR recovery system"
local program=""
local missing_programs=""
for program in "${PROGS[@]}" ; do
    # Skip empty values because without that test either
    # 'type' without argument succeeds and then 'basename' without argument fails
    # or 'type ""' with empty argument fails
    # so both result unwanted error messages and unwanted proceeding
    # cf. https://github.com/rear/rear/issues/2372
    test $program || continue
    # There are many programs in the PROGS array that may or may not exist on the original system
    # so that only those programs in the PROGS array that exist on the original system are tested:
    type $program || continue
    # Use the basename because the path within the recovery system is usually different compared to the path on the original system:
    program=$( basename $program )
    # Redirected stdin for login shell avoids motd welcome message, cf. https://github.com/rear/rear/issues/2120.
    chroot "$ROOTFS_DIR" /bin/bash --login -c "type $program" < /dev/null || missing_programs+=" $program"
done

# Report programs in the PROGS array that cannot be found as executable command within the recovery system:
if contains_visible_char "$missing_programs" ; then
    LogPrintError "There are programs that cannot be found as executable command in the ReaR recovery system"
    LogPrintError "$missing_programs"
    LogPrintError "ReaR recovery system in '$ROOTFS_DIR' lacks programs, check $RUNTIME_LOGFILE for details"
fi

# Testing that each program in the REQUIRED_PROGS array can be found as executable command within the recovery system:
DebugPrint "Testing that each program in the REQUIRED_PROGS array can be found as executable command within the ReaR recovery system"
local required_program=""
local missing_required_programs=""
local fatal_missing_program=""
for required_program in "${REQUIRED_PROGS[@]}" ; do
    # Skip empty values because without that test
    # either 'basename without argument fails
    # or 'basename ""' with empty argument falsely succeeds
    # so both result unwanted error messages and unwanted proceeding
    # cf. https://github.com/rear/rear/issues/2372
    test $required_program || continue
    # Use the basename because the path within the recovery system is usually different compared to the path on the original system:
    required_program=$( basename $required_program )
    # Redirected stdin for login shell avoids motd welcome message, cf. https://github.com/rear/rear/issues/2120.
    chroot "$ROOTFS_DIR" /bin/bash --login -c "type $required_program" < /dev/null || missing_required_programs+=" $required_program"
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
