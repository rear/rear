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
    has_binary udevadm && udevadm trigger $@ && return 0
    # then try an older way, older systems (e.g. SLES10) have 'udevtrigger'
    has_binary udevtrigger && udevtrigger $@ && return 0
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
    has_binary udevadm && udevadm settle $@ && return 0
    # then try an older way, older systems (e.g. SLES10) have 'udevsettle'
    has_binary udevsettle && udevsettle $@ && return 0
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

# Copy binaries given in $2 $3 ... to directory $1
function BinCopyTo () {
    local destdir="$1" binary=""
    test -d "$destdir" || Error "BinCopyTo destination '$destdir' is not a directory"
    while (( $# > 1 )) ; do
        shift
        binary="$1"
        # continue with the next one if a binary is empty or contains only blanks
        # there must be no double quotes for the test argument because test " " results true
        test $binary || continue
        if ! cp $verbose --archive --dereference --force "$binary" "$destdir" >&2 ; then
            Error "BinCopyTo failed to copy '$binary' to '$destdir'"
        fi
    done
}

# Determine all required shared objects (shared/dynamic libraries)
# for programs and/or shared objects (binaries) specified in $@.
# RequiredSharedOjects outputs the required shared objects on STDOUT.
# The output are absolute paths to the required shared objects.
# The output can also be symbolic links (also as absolute paths).
# In case of symbolic links only the link but not the link target is output.
function RequiredSharedOjects () {
    has_binary ldd || Error "Cannot run RequiredSharedOjects() because there is no ldd binary"
    Log "RequiredSharedOjects: Determining required shared objects"
    # Default ldd output (when providing more than one argument) has 5 cases.
    # Example (with an intentionally moved library to also get 'not found'):
    #  # mv /usr/lib64/libparted.so.2.0.0 /usr/lib64/libparted.so.2.0.0.away
    #  # ldd /usr/bin/cat /usr/sbin/parted | cat -n
    #     1  /usr/bin/cat:
    #     2          linux-vdso.so.1 (0x00007ffe13398000)
    #     3          libc.so.6 => /lib64/libc.so.6 (0x00007fda437a4000)
    #     4          /lib64/ld-linux-x86-64.so.2 (0x000055847e55e000)
    #     5  /usr/sbin/parted:
    #     6          linux-vdso.so.1 (0x00007ffde9f59000)
    #     7          libparted.so.2 => not found
    #     8          libtinfo.so.6 => /lib64/libtinfo.so.6 (0x00007f45c41b5000)
    #     9          libreadline.so.6 => /lib64/libreadline.so.6 (0x00007f45c3f6a000)
    #    10          libc.so.6 => /lib64/libc.so.6 (0x00007f45c3bc7000)
    #    11          libtinfo.so.5 => /lib64/libtinfo.so.5 (0x00007f45c3992000)
    #    12          /lib64/ld-linux-x86-64.so.2 (0x000055801c402000)
    # So we have to distinguish lines of the following form (indentation is done with tab '\t'):
    #  1. Line: "/path/to/binary:"                      -> current file argument for ldd
    #  2. Line: "       lib (mem-addr)"                 -> virtual library
    #  3. Line: "       lib => not found"               -> print error to stderr
    #  4. Line: "       lib => /path/to/lib (mem-addr)" -> print $3 '/path/to/lib'
    #  5. Line: "       /path/to/lib (mem-addr)"        -> print $1 '/path/to/lib'
    ldd "$@" | awk ' /^\t.+ => not found/ { print "Shared object " $1 " not found" > "/dev/stderr" }
                     /^\t.+ => \// { print $3 }
                     /^\t\// { print $1 } ' | sort -u
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

