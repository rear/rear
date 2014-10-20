# linux-functions.sh
#
# linux functions for Relax-and-Recover
#
# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# The way how we use Bash with lots of (nested) functions and read etc. seems to trigger a Bash
# bug that causes leaked file descriptors. lvm likes to complain about that but since we
# cannot fix the bash we suppress these lvm warnings:
#
# See:
#   http://osdir.com/ml/bug-bash-gnu/2010-04/msg00080.html
#   http://stackoverflow.com/questions/2649240/bash-file-descriptor-leak
#   http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=466138
export LVM_SUPPRESS_FD_WARNINGS=1


# check if udev is available in a sufficiently recent version
have_udev() {
	local relpath="$1"; shift
	if [ -d $relpath/etc/udev/rules.d ] && has_binary udevadm udevstart udevtrigger; then
		return 0
	fi
	return 1
}

# call udevtrigger
my_udevtrigger() {
	if has_binary udevadm; then
		udevadm trigger $@
	elif has_binary udevtrigger; then
		udevtrigger $@
	else
		# do what start_udev does on RHEL 4
		local pid=$(pidof -x udevd)
		if [ -n "$pid" ]; then
			kill $pid
		fi
		udevstart </dev/null >&8 2>&1
	fi
}

# call udevsettle
my_udevsettle() {
	if has_binary udevadm; then
		udevadm settle $@
	elif has_binary udevsettle; then
		udevsettle $@
	elif [ -e /sys/kernel/uevent_seqnum ] && [ -e /dev/.udev/uevent_seqnum ]; then
		# re-implement udevsettle for older systems
		local tries=0
		while [ "$(cat /sys/kernel/uevent_seqnum)" = "$(cat /dev/.udev/uevent_seqnum)" ] && [ "$tries" -lt 10 ]; do
			sleep 1
			let tries=tries+1
		done
	else
		sleep 10
	fi
}

# call udevinfo
my_udevinfo() {
	if has_binary udevadm; then
		udevadm info "$@"
	else
		udevinfo "$@"
	fi
}

# find the drivers for a device
FindDrivers() {
	have_udev || return 0
	local device="$1"; shift # device is /dev/sda
	local path="$(my_udevinfo -q path -n "$device")"
	if [ -z "$path" ]; then
		return 0
	fi
	my_udevinfo -a -p $path | \
		sed -ne '/DRIVER/!d; s/.*"\(.*\)".*/\1/; /^.\+/p; /PIIX_IDE/d;'
		# 1. filter all lines not containing DRIVER
		# 2. cut out everything between the ""
		# 3. filter empty lines
		# 4. fiter out unwanted modules
		# cool, eh :-)
	return $PIPESTATUS # return the status of the main udevinfo call instead
}

# find out which are the storage drivers to use on this system
# returns a list of storage drivers on STDOUT
# optionally $1 specifies the directory where to search for
# drivers files
FindStorageDrivers() {
	if (( ${#STORAGE_DRIVERS[@]} == 0 )); then
		grep -E 'kernel/drivers/(block|firewire|ide|ata|md|message|scsi|usb/storage)' /lib/modules/$KERNEL_VERSION/modules.builtin
		StopIfError "FindStorageDrivers called but STORAGE_DRIVERS is empty and no builtin storage modules found"
	fi 
	{
		while read module junk; do
			IsInArray "$module" "${STORAGE_DRIVERS[@]}" && echo $module
		done < <(lsmod)
		find ${1:-$VAR_DIR/recovery} -name storage_drivers -exec cat '{}' \; 2>/dev/null
	} | grep -v -E '(loop)' | sort -u
	# blacklist some more stuff here that came in the way on some systems
	return 0
	# always return 0 as the grep return code is meaningless
}

# Copy binaries given in $* to $1, stripping them on the way
BinCopyTo() {
	local dest="$1"
	[[ -d "$dest" ]]
	StopIfError "[BinCopyTo] Destination '$dest' not a directory"
	while (( $# > 1 )); do
		shift
		[[ -z "$1" ]] && continue # ignore blanks
		cp $v -a -L -f "$1" "$dest" >&2
		StopIfError "[BinCopyTo] Could not copy '$1' to '$dest'"
#		strip -s "$dest/$(basename "$1")" 2>&8
	done
	: # make sure that a failed strip won't fail the BinCopyTo
}

# Copy Modules given in $* to $1
ModulesCopyTo() {
	local dest="$1" dir=
	while (( $# > 1 )); do
		shift
		dir="$(dirname "$1")"
		[[ ! -d "$dest/$dir" ]] && mkdir -p $v "$dest/$dir"
		cp $v -a -L "$1" "$dest/$dir" >&2
		StopIfError "[ModulesCopyTo] Could not copy '$1' to '$dest'"
	done
}

# Check if module $1 is listed in $modules.
has_module () {
	case " $modules " in
		(*" $1 "*) return 0;;
	esac
	return 1
}

# Check if any of the modules in $* are listed in $modules.
has_any_module () {
	local module=
	for module in "$@"; do
		has_module "$module" && return 0
	done
}

# Add module $1 at the end of the module list.
add_module () {
	local module=
	for module in "$@"; do
		has_module "$module" || modules="$modules $module"
	done
}

# Install a binary file
cp_bin () {
	cp -a $v "$@" >&2

	# Remember the binaries installed. We need the list for checking
	# for dynamic libraries.
	while [ $# -gt 1 ]; do
		initrd_bins[${#initrd_bins[@]}]=$1
		shift
	done
}

# Resolve dynamic library dependencies. Returns a list of symbolic links
# to shared objects and shared object files for the binaries in $*.
# This is the function copied from mkinitrd off SuSE 9.3
SharedObjectFiles() {
	has_binary ldd
	StopIfError "Unable to find a working ldd binary."

	# Default ldd output (when providing more than one argument) has 5 cases:
	#  1. Line: "file:"                            -> file argument
	#  2. Line: "	lib =>  (mem-addr)"            -> virtual library
	#  3. Line: "	lib => not found"              -> print error to stderr
	#  4. Line: "	lib => /path/lib (mem-addr)"   -> print $3
	#  5. Line: "	/path/lib (mem-addr)"          -> print $1
	local -a initrd_libs=( $(ldd "$@" | awk '
		/^\t.+ => not found/ { print "WARNING: Dynamic library " $1 " not found" > "/dev/stderr" }
		/^\t.+ => \// { print $3 }
		/^\t\// { print $1 }
	' | sort -u) )

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
#		echo Deoptimizing "$lib" >&8
#	done

	local lib= link=
	for lib in "${initrd_libs[@]}"; do
		lib="${lib:1}"
		while [ -L "/$lib" ]; do
			echo $lib
			link="$(readlink "/$lib")"
			case "$link" in
				(/*) lib="${link:1}";;
				(*)  lib="${lib%/*}/$link";;
			esac
		done
		echo $lib
		echo $lib >&8
	done | sort -u
}


# Resolve module dependencies and parameters. Returns a list of modules and
# their parameters.
ResolveModules () {
	local kernel_version=$1 module=; shift

	for module in "$@"; do
		module=${module#.o}  # strip trailing ".o" just in case.
		module=${module#.ko}  # strip trailing ".ko" just in case.

		# Check if the module is not in the exclude list
		for emodule in ${EXCLUDE_MODULES[@]}; do
			if [ "$module" = "$emodule" ]; then
				continue 2
			fi
		done

		# Check if the module actually exists
		if ! modinfo $module &>/dev/null; then
			continue
		fi

		local with_modprobe_conf
		if [ -e $boot_dir/etc/modprobe.conf ]; then
			with_modprobe_conf="-C $boot_dir/etc/modprobe.conf"
			if [ "$print_modprobeconf" = 1 ]; then
				echo "Using $boot_dir/etc/modprobe.conf" >&8
				print_modprobeconf=0
			fi
		elif [ -e /etc/modprobe.conf ]; then
			with_modprobe_conf="-C /etc/modprobe.conf"
		fi
		module_list=$( \
			/sbin/modprobe $with_modprobe_conf --ignore-install \
				--set-version $kernel_version \
				--show-depends $module 2>&8 \
				| awk '/^insmod / { print $2 }' | sort -u)

		if [ -z "$module_list" ]; then
			case $module in
				(scsi_mod|sd_mod|md)  # modularized in 2.4.21
					# These modules were previously compiled into the kernel,
					# and were modularized later. They will be missing in older
					# kernels; ignore error messages.
					;;
				(ext2|ext3|reiserfs|jfs|xfs)
					# they are there or not
					;;
				(xfs_support)  # gone in 2.4.20
					# This module does no longer exist. Do not produce an error
					# message, but warn that it should be removed manually.
					echo -n "Warning: Module $module no longer exists, and" \
						"should be removed " >&8
					if [ -e /etc/sysconfig/kernel ]; then
						echo "from /etc/sysconfig/kernel." >&8
					elif [ -e /etc/rc.config ]; then
						echo "from /etc/rc.config." >&8
					else
						echo "." >&8
					fi
					;;
				(*)
					echo "Cannot determine dependencies of module $module." \
						"Is modules.dep up to date?" >&2
					find /lib/modules/$kernel_version -name $module.\*
					;;
			esac
		fi
		echo "$module_list"
		echo "Module $module depends on $module_list" >&8
	done \
	| awk ' # filter duplicates: we must not reorder modules here!
		$1 in seen  { next }
		{
			seen[$1]=1
			print
		}
	'
}

function rpmtopdir () {
	rpmdb -E '%{_topdir}'
}

# Provide a shell, with custom exit-prompt and history
rear_shell() {
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
function filesystem_name() {
    local path=$1
    local fs=$(df -Pl "$path" | awk 'END { print $6 }')
    if [[ -z "$fs" ]]; then
        echo "/"
    else
        echo "$fs"
    fi
}
