# linux-functions.sh
#
# linux functions for Relax & Recover
#
#    Relax & Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax & Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax & Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

# check if udev is available in a sufficiently recent version
have_udev() {
	local relpath="$1"; shift
	if [ -d $relpath/etc/udev/rules.d ] && \
		{ type -p udevadm || type -p udevtrigger || type -p udevstart; } &>/dev/null; then
		return 0
	fi
	return 1
}

# call udevtrigger
my_udevtrigger() {
	if type -p udevadm &>/dev/null; then
		udevadm trigger $@
	elif type -p udevtrigger &>/dev/null; then
		udevtrigger $@
	else
		# do what start_udev does on RHEL 4
		local pid=$(pidof -x udevd)
		if [ -n "$pid" ]; then
			kill $pid
		fi
		udevstart </dev/null &>/dev/null
	fi
}

# call udevsettle
my_udevsettle() {
	if type -p udevadm &>/dev/null; then
		udevadm settle $@
	elif type -p udevsettle &>/dev/null; then
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
	if type -p udevadm &>/dev/null; then
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
		sed -ne '/DRIVER/!d;s/.*"\(.*\)".*/\1/;/^.\+/p' | \
		# 1. filter all lines not containing DRIVER
		# 2. cut out everything between the ""
		# 3. filter empty lines
		# cool, eh :-)
		sed -e "/PIIX_IDE/d;"
		# filter out unwanted modules
		# could be added to the previous sed, but like this
		# it is easier to read
	return $PIPESTATUS # return the status of the main udevinfo call instead
}

# find out which are the storage drivers to use on this system
# returns a list of storage drivers on STDOUT
# optionally $1 specifies the directory where to search for
# drivers files
FindStorageDrivers() {
	[ "$STORAGE_DRIVERS" ]
	StopIfError "FindStorageDrivers called but STORAGE_DRIVERS is empty"
	{ 
		while read module junk; do
			IsInArray "$module" "${STORAGE_DRIVERS[@]}" && echo $module
		done < <(lsmod)
		find ${1:-$VAR_DIR/recovery} -name drivers -exec cat '{}' \;
	} | sort -u | grep -v -E '(loop)'
	# blacklist some more stuff here that came in the way on some systems
	return 0
	# always return 0 as the grep return code is meaningless
}

# Copy binaries given in $* to $1, stripping them on the way
BinCopyTo() {
	local dest="$1" src=; shift
	[ -d "$dest" ]
	StopIfError "[BinCopyTo] Destination '$dest' not a directory"
	for src in "$@"; do
		test -z "$src" && continue # ignore blanks
		[ -x "$src" ]
		StopIfError "[BinCopyTo] Source '$src' is not an executable"
		cp -v -a -L "$src" "$dest"
		StopIfError "[BinCopyTo] Could not copy '$src' to '$dest'"
		strip -s "$dest/$(basename "$src")" 2>/dev/null
	done
	: # make sure that a failed strip won't fail the BinCopyTo
}

# Copy libraries given in $* to $1, stripping them on the way
# like BinCopyTo, but copy symlinks as such, since some libraries
LibCopyTo() {
	local dest="$1" src=; shift
	[ -d "$dest" ]
	StopIfError "[LibCopyTo] Destination '$dest' not a directory"
	for src in "$@"; do
		test -z "$src" && continue # ignore blanks
		[ -r "$src" ]
		StopIfError "[LibCopyTo] Source '$src' is not readable"
		if ! cmp "$dest/$(basename "$src")" "$src" 2>/dev/null; then
			cp -v -a "$src" "$dest"
			StopIfError "[LipCopyTo] Could not copy '$src' to '$dest'"
		fi
		test ! -L "$dest/$(basename "$src")" && strip -s "$dest/$(basename "$src")"
	done
	: # make sure that a failed strip won't fail the BinCopyTo
}

# Copy Modules given in $* to $1
ModulesCopyTo() {
	local dest="$1" dir= src=; shift
	for src in "$@"; do
		dir="$(dirname "$src")"
		mkdir -p $v "$dest/$dir"
		cp -a -L -v "/$src" "$dest/$dir"
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
	cp -a "$@"

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
	local ldd=$(type -p ldd 2>/dev/null)
	[[ "$ldd" && -x "$ldd" ]]
	StopIfError "Unable to find a working ldd binary."

	local initrd_libs=( $(
		$ldd "$@" \
		| sed -ne 's:\t\(.* => \)\?\(/.*\) (0x[0-9a-f]*):\2:p'
	) )

	# Evil hack: On some systems we have generic as well as optimized
	# libraries, but the optimized libraries may not work with all
	# kernel versions (e.g., the NPTL glibc libraries don't work with
	# a 2.4 kernel). Use the generic versions of the libraries in the
	# initrd (and guess the name).
	local lib= n= optimized=
	for ((n=0; $n<${#initrd_libs[@]}; n++)); do
		lib=${initrd_libs[$n]}
		optimized="$(echo "$lib" | sed -e 's:.*/\([^/]\+/\)[^/]\+$:\1:')"
		lib=${lib/$optimized/}
		if [ "${optimized:0:3}" != "lib" -a -f "$lib" ]; then
			#echo "[Using $lib instead of ${initrd_libs[$n]}]" >&2
			initrd_libs[$n]="${lib/$optimized/}"
		fi
		echo Deoptimizing "$lib" >&8
	done

	local link=
	for lib in "${initrd_libs[@]}"; do
		case "$lib" in
			(linux-gate*)
				# This library is mapped into the process by the kernel
				# for vsyscalls (i.e., syscalls that don't need a user/
				# kernel address space transition) in 2.6 kernels.
				continue
				;;
			(/*)
				lib="${lib:1}"
				;;
			(*)
				# Library could not be found.
				echo "WARNING: Dynamic library $lib not found" >&8
				continue
				;;
		esac

		while [ -L "/$lib" ]; do
			echo $lib
			link="$(readlink "/$lib")"
			if [ x"${link:0:1}" == x"/" ]; then
				lib=${link#/}
			else
				lib="${lib%/*}/$link"
			fi
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
				--show-depends $module 2> /dev/null \
				| sed -ne 's:.*insmod /\?::p' )

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
					find /lib/modules/$kernel_version -name $module.\* | sed -e 's#^/##'
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
