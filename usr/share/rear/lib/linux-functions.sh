# linux-functions.sh
#
# linux functions for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# The way how we use bash with lots of (nested) functions and read etc. seems to trigger a bash
# bug that causes leaked file descriptors. lvm likes to complain about that but since we
# cannot fix the bash we suppress these lvm warnings, see
# http://osdir.com/ml/bug-bash-gnu/2010-04/msg00080.html
# http://stackoverflow.com/questions/2649240/bash-file-descriptor-leak
# http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=466138
export LVM_SUPPRESS_FD_WARNINGS=1

# check if udev is available in a sufficiently recent version
# has_binary succeeds when one of its arguments exists
# newer systems (e.g. SLES11) have udevadm
# older systems (e.g. SLES10 or RHEL 4) have udevtrigger udevsettle udevinfo or udevstart
function have_udev () {
    test -d /etc/udev/rules.d && has_binary udevadm udevtrigger udevsettle udevinfo udevstart && return 0
    return 1
}

# try calling 'udevadm trigger' or 'udevtrigger' or fallback
# but waiting for udev and "kicking udev" both miss the point
# see https://github.com/rear/rear/issues/791
function my_udevtrigger () {
    # first try the most current way, newer systems (e.g. SLES11) have 'udevadm trigger'
    has_binary udevadm && udevadm trigger "$@" && return 0
    # then try an older way, older systems (e.g. SLES10) have 'udevtrigger'
    has_binary udevtrigger && udevtrigger "$@" && return 0
    # as first fallback do what start_udev does on RHEL 4
    if has_binary udevstart ; then
        local udevd_pid=$( pidof -x udevd )
        test "$udevd_pid" && kill $udevd_pid
        udevstart </dev/null &>/dev/null && return 0
    fi
    # as final fallback just wait a bit and hope for the best
    sleep 10
}

# try calling 'udevadm settle' or 'udevsettle' or fallback
# but waiting for udev and "kicking udev" both miss the point
# see https://github.com/rear/rear/issues/791
function my_udevsettle () {
    # first try the most current way, newer systems (e.g. SLES11) have 'udevadm settle'
    has_binary udevadm && udevadm settle "$@" && return 0
    # then try an older way, older systems (e.g. SLES10) have 'udevsettle'
    has_binary udevsettle && udevsettle "$@" && return 0
    # as first fallback re-implement udevsettle for older systems
    if [ -e /sys/kernel/uevent_seqnum ] && [ -e /dev/.udev/uevent_seqnum ] ; then
        local tries=0
        while [ "$( cat /sys/kernel/uevent_seqnum )" = "$( cat /dev/.udev/uevent_seqnum )" ] && [ "$tries" -lt 10 ] ; do
            sleep 1
            let tries=tries+1
        done
        return 0
    fi
    # as final fallback just wait a bit and hope for the best
    sleep 10
}

# call 'udevadm info' or 'udevinfo'
function my_udevinfo () {
    # first try the most current way, newer systems (e.g. SLES11) have 'udevadm info'
    if has_binary udevadm ; then
        udevadm info "$@"
        return 0
    fi
    # then try an older way, older systems (e.g. SLES10) have 'udevinfo'
    if has_binary udevinfo ; then
        udevinfo "$@"
        return 0
    fi
    # no fallback
    return 1
}

# find out which are the storage drivers to use on this system
# returns a list of storage drivers on STDOUT
# optionally $1 specifies the directory where to search for
# drivers files
function FindStorageDrivers () {
    # The special user setting MODULES=( 'no_modules' ) enforces that
    # no kernel modules get included in the rescue/recovery system
    # regardless of what modules are currently loaded.
    # Test the first MODULES array element because other scripts
    # in particular rescue/GNU/Linux/240_kernel_modules.sh
    # already appended other modules to the MODULES array:
    test "no_modules" = "$MODULES" && return

    if (( ${#STORAGE_DRIVERS[@]} == 0 )) ; then
        if ! grep -E 'kernel/drivers/(block|firewire|ide|ata|md|message|scsi|usb/storage)' /lib/modules/$KERNEL_VERSION/modules.builtin ; then
            Error "FindStorageDrivers called but STORAGE_DRIVERS is empty and no builtin storage modules found"
        fi
    fi
    {
        while read module junk ; do
            IsInArray "$module" "${STORAGE_DRIVERS[@]}" && echo $module
        done < <(lsmod)
        find ${1:-$VAR_DIR/recovery} -name storage_drivers -exec cat '{}' \; 2>/dev/null
    } | grep -v -E '(loop)' | sort -u
    # blacklist some more stuff here that came in the way on some systems
    return 0
    # always return 0 as the grep return code is meaningless
}

# Determine all required shared objects (shared/dynamic libraries)
# for programs and/or shared objects (binaries) specified in $@.
# RequiredSharedObjects outputs the set of required shared objects on STDOUT.
# The output are absolute paths to the required shared objects.
# The output can also be symbolic links (also as absolute paths).
# In case of symbolic links only the link but not the link target is output.
function RequiredSharedObjects () {
    has_binary ldd || Error "Cannot run RequiredSharedObjects() because there is no ldd binary"
    Log "RequiredSharedObjects: Determining required shared objects"
    # It uses 'ldd' to determine all required shared objects because 'ldd' outputs
    # also transitively required shared objects i.e. libraries needed by libraries,
    # e.g. for /usr/sbin/parted also the libraries needed by the libparted library:
    #  # ldd /usr/sbin/parted
    #          linux-vdso.so.1 (0x00007ffd68fe1000)
    #          libparted.so.2 => /usr/lib64/libparted.so.2 (0x00007f0c72bee000)
    #          libtinfo.so.6 => /lib64/libtinfo.so.6 (0x00007f0c729c4000)
    #          libreadline.so.6 => /lib64/libreadline.so.6 (0x00007f0c72778000)
    #          libc.so.6 => /lib64/libc.so.6 (0x00007f0c723d5000)
    #          libuuid.so.1 => /usr/lib64/libuuid.so.1 (0x00007f0c721d0000)
    #          libdevmapper.so.1.02 => /lib64/libdevmapper.so.1.02 (0x00007f0c71f85000)
    #          libblkid.so.1 => /usr/lib64/libblkid.so.1 (0x00007f0c71d43000)
    #          libtinfo.so.5 => /lib64/libtinfo.so.5 (0x00007f0c71b0f000)
    #          /lib64/ld-linux-x86-64.so.2 (0x000055eff2882000)
    #          libselinux.so.1 => /lib64/libselinux.so.1 (0x00007f0c718e8000)
    #          libudev.so.1 => /usr/lib64/libudev.so.1 (0x00007f0c716c8000)
    #          libpthread.so.0 => /lib64/noelision/libpthread.so.0 (0x00007f0c714ab000)
    #          libpcre.so.1 => /usr/lib64/libpcre.so.1 (0x00007f0c71244000)
    #          libdl.so.2 => /lib64/libdl.so.2 (0x00007f0c71040000)
    #          libcap.so.2 => /lib64/libcap.so.2 (0x00007f0c70e3b000)
    #          librt.so.1 => /lib64/librt.so.1 (0x00007f0c70c32000)
    #          libm.so.6 => /lib64/libm.so.6 (0x00007f0c70935000)
    #          libresolv.so.2 => /lib64/libresolv.so.2 (0x00007f0c7071e000)
    #  # file /usr/lib64/libparted.so.2
    #  /usr/lib64/libparted.so.2: symbolic link to `libparted.so.2.0.0'
    #  # mv /usr/lib64/libparted.so.2.0.0 /usr/lib64/libparted.so.2.0.0.away
    #  # ldd /usr/sbin/parted /usr/lib64/libparted.so.2.0.0.away
    #  /usr/sbin/parted:
    #          linux-vdso.so.1 (0x00007ffc38505000)
    #          libparted.so.2 => not found
    #          libtinfo.so.6 => /lib64/libtinfo.so.6 (0x00007fe0f4b5e000)
    #          libreadline.so.6 => /lib64/libreadline.so.6 (0x00007fe0f4913000)
    #          libc.so.6 => /lib64/libc.so.6 (0x00007fe0f4570000)
    #          libtinfo.so.5 => /lib64/libtinfo.so.5 (0x00007fe0f433b000)
    #          /lib64/ld-linux-x86-64.so.2 (0x000055e2549e2000)
    #  /usr/lib64/libparted.so.2.0.0.away:
    #          linux-vdso.so.1 (0x00007fffdbb8f000)
    #          libuuid.so.1 => /usr/lib64/libuuid.so.1 (0x00007f3c9a87d000)
    #          libdevmapper.so.1.02 => /lib64/libdevmapper.so.1.02 (0x00007f3c9a633000)
    #          libblkid.so.1 => /usr/lib64/libblkid.so.1 (0x00007f3c9a3f0000)
    #          libc.so.6 => /lib64/libc.so.6 (0x00007f3c9a04d000)
    #          /lib64/ld-linux-x86-64.so.2 (0x0000563ffc5f1000)
    #          libselinux.so.1 => /lib64/libselinux.so.1 (0x00007f3c99e27000)
    #          libudev.so.1 => /usr/lib64/libudev.so.1 (0x00007f3c99c06000)
    #          libpthread.so.0 => /lib64/noelision/libpthread.so.0 (0x00007f3c999e9000)
    #          libpcre.so.1 => /usr/lib64/libpcre.so.1 (0x00007f3c99783000)
    #          libdl.so.2 => /lib64/libdl.so.2 (0x00007f3c9957e000)
    #          libcap.so.2 => /lib64/libcap.so.2 (0x00007f3c99379000)
    #          librt.so.1 => /lib64/librt.so.1 (0x00007f3c99171000)
    #          libm.so.6 => /lib64/libm.so.6 (0x00007f3c98e73000)
    #          libresolv.so.2 => /lib64/libresolv.so.2 (0x00007f3c98c5c000)
    # The 'ldd' output (when providing more than one argument) has 5 cases.
    # So we have to distinguish lines of the following form (indentation is done with tab '\t'):
    #  1. Line: "/path/to/binary:"                                 -> current file argument for ldd
    #  2. Line: "        lib (mem-addr)"                           -> virtual library
    #  3. Line: "        lib => not found"                         -> print error to stderr
    #  4. Line: "        lib => /path/to/lib (mem-addr)"           -> print $3 '/path/to/lib'
    #  5. Line: "        /path/to/lib => /path/to/lib2 (mem-addr)" -> print $3 '/path/to/lib2'
    #  6. Line: "        /path/to/lib (mem-addr)"                  -> print $1 '/path/to/lib'
    local file_for_ldd=""
    local file_owner_name=""
    # It is crucial to append to /dev/$DISPENSABLE_OUTPUT_DEV (cf. 'Print' in lib/_input-output-functions.sh):
    for file_for_ldd in "$@" ; do
        # Skip non-regular files like directories, device files, and non-existent files
        # cf. similar code in build/GNU/Linux/100_copy_as_is.sh
        # but here symbolic links must not be skipped (e.g. /sbin/mkfs.ext2 -> /usr/sbin/mkfs.ext2)
        # otherwise there would be binaries in the recovery system without required libraries:
        test -f "$file_for_ldd" || continue
        # Skip the ldd test for kernel modules and firmware files
        # which could happen via COPY_AS_IS+=( /lib/firmware/my_hardware )
        # cf. the code in build/default/990_verify_rootfs.sh
        egrep -q '/lib/modules/|/lib.*/firmware/' <<<"$file_for_ldd" && continue
        # Skip files that are not owned by a trusted user to mitigate possible ldd security issues
        # because some versions of ldd may directly execute the file (see "man ldd")
        # which could lead to the execution of arbitrary programs as user 'root'
        # in particular when directories are specified in COPY_AS_IS that may contain
        # unexpected files like programs from arbitrary (possibly untrusted) users
        # like COPY_AS_IS+=( /home/JohnDoe ) when JohnDoe is not a trusted user.
        if test "$TRUSTED_FILE_OWNERS" ; then
            file_owner_name="$( stat -c %U $file_for_ldd )"
            if ! IsInArray "$file_owner_name" "${TRUSTED_FILE_OWNERS[@]}" ; then
                Log "RequiredSharedObjects: Skipping 'ldd' for '$file_for_ldd' (owner '$file_owner_name' not in TRUSTED_FILE_OWNERS)"
                continue
            fi
        fi
        ldd $file_for_ldd
        # It is crucial to filter the output of all those ldd calls in the 'for' loop
        # through one "awk ... | sort -u" pipe to output the set of required shared objects
        # (a mathematical set does not contain duplicate elements):
    done 2>>/dev/$DISPENSABLE_OUTPUT_DEV | awk ' /^\t.+ => not found/ { print "Shared object " $1 " not found" > "/dev/stderr" }
                                                 /^\t.+ => \// { print $3 }
                                                 /^\t\// && !/ => / { print $1 } ' | sort -u
}

# Provide a shell, with custom exit-prompt and history
function rear_shell () {
    local prompt=$1
    local history=$2
    # Set fallback exit prompt:
    test "$prompt" || prompt="Are you sure you want to exit the Relax-and-Recover shell ?"
    # Set some history:
    local histfile="$TMP_DIR/.bash_history"
    echo "exit" >$histfile
    test "$history" && echo -e "exit\n$history" >$histfile
    # Setup .bashrc:
    local bashrc="$TMP_DIR/.bashrc"
    cat <<EOF >$bashrc
export PS1="rear> "
ask_exit() {
    read -p "$prompt " REPLY
    if [[ "\$REPLY" =~ ^[Yy1] ]] ; then
        \exit
    fi
}
rear() {
    echo "ERROR: You cannot run rear from within the Relax-and-Recover shell !" >&2
}
alias exit=ask_exit
alias halt=ask_exit
alias poweroff=ask_exit
alias reboot=ask_exit
alias shutdown=ask_exit
cd $VAR_DIR
EOF
    # Run 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user
    # to get input from the user and to show output to the user (cf. _input-output-functions.sh):
    HISTFILE="$histfile" bash --noprofile --rcfile $bashrc 0<&6 1>&7 2>&8
}

# Return the filesystem name related to a path
function filesystem_name () {
    local path=$1
    local fs=$(df -Pl "$path" | awk 'END { print $6 }')
    if [[ -z "$fs" ]]; then
        echo "/"
    else
        echo "$fs"
    fi
}

