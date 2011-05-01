# #20_copy_binaries_libraries.sh
#
# copy binaries and libraries for Relax & Recover
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

Log "Copy program files & libraries"
ProgressStart "Copy program files & libraries"
{
# calculate binaries from needed progs
declare -a BINARIES
c=0
for k in "${PROGS[@]}" "${REQUIRED_PROGS[@]}"; do
	file="$(type -p "$k")"
	if test -x "$file" ; then
		BINARIES[$c]="$file"
		let c++
		echo "Found $file"
	fi
done
} 1>&8
# copy binaries
Log "Binaries: ${BINARIES[@]}"
BinCopyTo "$ROOTFS_DIR/bin" "${BINARIES[@]}"  1>&8
ProgressStopIfError $PIPESTATUS "Could not copy binaries"

# split libs into lib and lib64 paths
# I know, our modular design demands to split this into multiple files
# but I prefer to do that when a 3rd variety has to be dealt with.
LIBS=()
LIBS32=()
LIBS64=()
for lib in ${LIBS[@]} $(SharedObjectFiles "${BINARIES[@]}" | sed -e 's#^#/#' ) ; do
	# this is a list of library filenames like this:
	# /lib/libc-2.11.1.so
	# /lib64/ld-2.11.1.so
	# /lib32/libc-2.11.1.so
	# /usr/lib/libgthread-2.0.so.0
	#
	# we sort that into LIBS, LIBS32 and LIBS64 accordingly
	ldir="${lib%/*}" # dirname
	ldir="${ldir##*/}" # basename
	case "$ldir" in
		(lib)	LIBS=( ${LIBS[@]} $lib ) ;;
		(lib32)	LIBS32=( ${LIBS32[@]} $lib ) ;;
		(lib64)	LIBS64=( ${LIBS64[@]} $lib ) ;;
		(*)	BugError "Unkown library type '$ldir' encountered" ;;
	esac
done

Log "Libraries: ${LIBS[@]}"
if test "$LIBS" ; then
	LibCopyTo "$ROOTFS_DIR/lib" ${LIBS[@]} 1>&8 
	ProgressStopIfError $PIPESTATUS "Could not copy libraries"
fi
Log "Libraries(32): ${LIBS32[@]}"
if test "$LIBS32" ; then
	LibCopyTo "$ROOTFS_DIR/lib32" ${LIBS32[@]} 1>&8 
	ProgressStopIfError $PIPESTATUS "Could not copy 32bit libraries"
fi
Log "Libraries(64): ${LIBS64[@]}"
if test "$LIBS64" ; then
	LibCopyTo "$ROOTFS_DIR/lib64" ${LIBS64[@]} 1>&8
	ProgressStopIfError $PIPESTATUS "Could not copy 64bit libraries"
fi
ldconfig $v -r "$ROOTFS_DIR" 1>&8 
ProgressStopOrError $PIPESTATUS "Could not configure libraries with ldconfig"


