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

# Copy modules given in $2 $3 ... to directory $1
function ModulesCopyTo () {
    local destdir="$1" moddir=""
    test -d "$destdir" || Error "ModulesCopyTo destination '$destdir' is not a directory"
    while (( $# > 1 )) ; do
        shift
        modfile="$1"
        # continue with the next one if a module is empty or contains only blanks
        # there must be no double quotes for the test argument because test " " results true
        test $modfile || continue
        moddir="$( dirname "$modfile" )"
        test -d "$destdir/$moddir" || mkdir -p $v "$destdir/$moddir"
        if ! cp $verbose --archive --dereference "$modfile" "$destdir/$moddir" >&2 ; then
            Error "ModulesCopyTo failed to copy '$modfile' to '$destdir/$moddir'"
        fi
    done
}

# Resolve dynamic library dependencies. Returns a list of symbolic links
# to shared objects and shared object files for the binaries in $@.
# This is the function copied from mkinitrd off SUSE 9.3
function SharedObjectFiles () {
    has_binary ldd || Error "SharedObjectFiles failed because there is no ldd binary"

    # Default ldd output (when providing more than one argument) has 5 cases:
    #  1. Line: "file:"                            -> file argument
    #  2. Line: "	lib =>  (mem-addr)"            -> virtual library
    #  3. Line: "	lib => not found"              -> print error to stderr
    #  4. Line: "	lib => /path/lib (mem-addr)"   -> print $3
    #  5. Line: "	/path/lib (mem-addr)"          -> print $1
    local -a initrd_libs=( $( ldd "$@" | awk '
            /^\t.+ => not found/ { print "WARNING: Dynamic library " $1 " not found" > "/dev/stderr" }
            /^\t.+ => \// { print $3 }
            /^\t\// { print $1 }
        ' | sort -u ) )

    ### FIXME: Is this still relevant today ? If so, make it more specific !

    # Evil hack: On some systems we have generic as well as optimized
    # libraries, but the optimized libraries may not work with all
    # kernel versions (e.g., the NPTL glibc libraries don't work with
    # a 2.4 kernel). Use the generic versions of the libraries in the
    # initrd (and guess the name).
#	local lib= n= optimized=
#	for ((n=0; $n<${#initrd_libs[@]}; n++)); do
#		lib=${initrd_libs[$n]}
#		optimized="$(echo "$lib" | sed -e 's:.*/\([^/]\+/\)[^/]\+$:\1:')"
#		lib=${lib/$optimized/}
#		if [ "${optimized:0:3}" != "lib" -a -f "$lib" ]; then
#			#echo "[Using $lib instead of ${initrd_libs[$n]}]" >&2
#			initrd_libs[$n]="${lib/$optimized/}"
#		fi
#		echo Deoptimizing "$lib" >&2
#	done

    local lib="" link=""
    for lib in "${initrd_libs[@]}" ; do
        lib="${lib:1}"
        while [ -L "/$lib" ] ; do
            echo $lib
            link="$( readlink "/$lib" )"
            case "$link" in
                (/*) lib="${link:1}" ;;
                (*)  lib="${lib%/*}/$link" ;;
            esac
        done
        echo $lib
        echo $lib >&2
    done | sort -u
}

# Resolve module dependencies and parameters
# for modules given in $2 $3 ... for kernel version $1
# Returns a list of modules and their parameters.
function ResolveModules () {
    local kernel_version=$1 module=""
    shift
    for module in "$@" ; do
        # Strip trailing ".o" if there:
        module=${module#.o}
        # Strip trailing ".ko" if there:
        module=${module#.ko}
        # Check if the module is not in the exclude list:
        for exclude_module in "${EXCLUDE_MODULES[@]}" ; do
            # Continue with the next module if the current one is in EXCLUDE_MODULES:
            test "$module" = "$exclude_module" && continue 2
        done
        # Continue with the next module if the current one does not exist:
        modinfo $module &>/dev/null || continue
        # Use modprobe.conf if available:
        local with_modprobe_conf=""
        test -e /etc/modprobe.conf && with_modprobe_conf="-C /etc/modprobe.conf"
        # Resolve module dependencies and parameters:
        module_list=$( /sbin/modprobe $with_modprobe_conf --ignore-install --set-version $kernel_version \
                                      --show-depends $module 2>/dev/null | awk '/^insmod / { print $2 }' | sort -u )
        if test "$module_list" ; then
            # Output module dependencies if not empty:
            echo "$module_list"
            echo "Module $module depends on $module_list" >&2
        else
            # Fallback behaviour if module_list is empty:
            case $module in
                (scsi_mod|sd_mod|md)
                    # modularized in 2.4.21
                    # These modules were previously compiled into the kernel,
                    # and were modularized later. They will be missing in older
                    # kernels; ignore error messages.
                    ;;
                (ext2|ext3|ext4|reiserfs|btrfs|jfs|xfs)
                    # they are there or not
                    ;;
                (xfs_support)
                    # gone in 2.4.20
                    # This module does no longer exist. Do not produce an error
                    # message, but warn that it should be removed manually.
                    echo -n "Warning: Module $module no longer exists and should be removed" >&2
                    if [ -e /etc/sysconfig/kernel ] ; then
                        echo " from /etc/sysconfig/kernel." >&2
                    elif [ -e /etc/rc.config ] ; then
                        echo " from /etc/rc.config." >&2
                    else
                        echo "." >&2
                    fi
                    ;;
                (*)
                    echo "Cannot determine dependencies of module $module. Is modules.dep up to date?" >&2
                    # Fallback output is the plain module file without dependencies:
                    find /lib/modules/$kernel_version -name $module.\*
                    ;;
            esac
        fi
    done | awk '!x[$0]++'
    # That obfuscated awk command removes duplicates without sorting
    # because we must not reorder the modules here.
    # Explanation: This command is telling awk which lines to print.
    # The variable $0 holds the entire contents of a line and square brackets are array access.
    # So, for each line of the file, the node of the array x is incremented
    # and the line printed if the content of that node was not (!) previously set.
    # This awk command would be easier to understand: awk '!($0 in x){x[$0]++; print $0}
    # and with traditional commands it could be: cat -n | sort -uk2 | sort -nk1 | cut -f2-
    # (add line numbers, remove duplicates, resort according to line numbers, output without line numbers)
    # see http://stackoverflow.com/questions/11532157/unix-removing-duplicate-lines-without-sorting
    # and http://www.unixcl.com/2008/03/remove-duplicates-without-sorting-file.html
}

# Provide a shell, with custom exit-prompt and history
function rear_shell () {
    local prompt=$1
    local history=$2

    if [[ -z "$prompt" ]]; then
        prompt="Are you sure you want to exit the Relax-and-Recover shell ?"
    fi

    local histfile="$TMP_DIR/.bash_history"
    if [[ "$history" ]]; then
        echo -e "exit\n$history" >$histfile
    else
        echo "exit" >$histfile
    fi

    local bashrc="$TMP_DIR/.bashrc"
    cat <<EOF >$bashrc
export PS1="rear> "
ask_exit() {
    read -p "$prompt " REPLY
    if [[ "\$REPLY" =~ ^[Yy1] ]]; then
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

    HISTFILE="$histfile" bash --noprofile --rcfile $bashrc 8>&- 7>&- 2>&1
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

